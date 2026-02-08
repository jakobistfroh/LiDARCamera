import Foundation
import ARKit
import UIKit

final class RawDataSessionRecorder {

    private let videoRecorder = ARFrameVideoRecorder()
    private let maskProcessor: RawDepthMaskProcessor

    private let depthMaskFPS: Int
    private let depthMaskInterval: TimeInterval

    private var recordingFolderURL: URL?
    private var videoURL: URL?
    private var depthMaskURL: URL?
    private var timestampsURL: URL?
    private var metadataURL: URL?
    private var zipURL: URL?

    private var startTimestamp: TimeInterval?
    private var lastMaskTimestamp: TimeInterval = -.greatestFiniteMagnitude

    private var videoTimestamps: [FrameTimestamp] = []
    private var depthMaskTimestamps: [FrameTimestamp] = []
    private var videoFrameIndex = 0
    private var depthMaskFrameIndex = 0

    private var maskHandle: FileHandle?
    private var baseMetadata: RawMetadata?

    init(depthMaskFPS: Int = 10, maskWidth: Int = 160, maskHeight: Int = 120, percentile: Float = 0.15, deltaMeters: Float = 0.3) {
        self.depthMaskFPS = depthMaskFPS
        self.depthMaskInterval = 1.0 / Double(depthMaskFPS)
        self.maskProcessor = RawDepthMaskProcessor(
            width: maskWidth,
            height: maskHeight,
            percentile: percentile,
            deltaMeters: deltaMeters
        )
    }

    func prepareRecording(cameraResolution: CGSize, videoFPS: Int, lidarAvailable: Bool) throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
        let index = RawDataUtilities.nextRawRecordingIndex(in: tempDir)
        let folderName = String(format: "recording_raw_%03d", index)

        let folderURL = tempDir.appendingPathComponent(folderName, isDirectory: true)
        let videoURL = folderURL.appendingPathComponent("video.mp4")
        let depthMaskURL = folderURL.appendingPathComponent("depth_mask.bin")
        let timestampsURL = folderURL.appendingPathComponent("timestamps.json")
        let metadataURL = folderURL.appendingPathComponent("metadata.json")
        let zipURL = tempDir.appendingPathComponent("\(folderName).zip")

        try? fm.removeItem(at: folderURL)
        try? fm.removeItem(at: zipURL)
        try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
        fm.createFile(atPath: depthMaskURL.path, contents: nil)

        guard let handle = try? FileHandle(forWritingTo: depthMaskURL) else {
            throw NSError(domain: "RawDataSessionRecorder", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Cannot create depth_mask.bin"])
        }

        self.recordingFolderURL = folderURL
        self.videoURL = videoURL
        self.depthMaskURL = depthMaskURL
        self.timestampsURL = timestampsURL
        self.metadataURL = metadataURL
        self.zipURL = zipURL
        self.maskHandle = handle
        self.startTimestamp = nil
        self.lastMaskTimestamp = -.greatestFiniteMagnitude
        self.videoTimestamps.removeAll()
        self.depthMaskTimestamps.removeAll()
        self.videoFrameIndex = 0
        self.depthMaskFrameIndex = 0

        let params = DepthMaskParameters(
            percentile: Double(maskProcessor.percentile),
            deltaMeters: Double(maskProcessor.deltaMeters),
            width: maskProcessor.width,
            height: maskProcessor.height
        )
        self.baseMetadata = RawMetadata(
            deviceModel: RawDataUtilities.deviceModelIdentifier(),
            iosVersion: UIDevice.current.systemVersion,
            cameraResolution: "\(Int(cameraResolution.width))x\(Int(cameraResolution.height))",
            videoFPS: videoFPS,
            depthMaskFPS: depthMaskFPS,
            orientation: RawDataUtilities.orientationString(),
            lidarAvailable: lidarAvailable,
            depthMaskParameters: params
        )
    }

    func process(frame: ARFrame) {
        guard let videoURL else { return }

        if startTimestamp == nil {
            startTimestamp = frame.timestamp
        }

        let relativeTimestamp = max(0, frame.timestamp - (startTimestamp ?? frame.timestamp))

        if !videoRecorder.isRecording {
            do {
                try videoRecorder.start(with: frame.capturedImage, outputURL: videoURL)
            } catch {
                print("Raw video start failed: \(error)")
                return
            }
        }

        if videoRecorder.append(pixelBuffer: frame.capturedImage, timestampSeconds: relativeTimestamp) {
            videoTimestamps.append(FrameTimestamp(index: videoFrameIndex, timestamp: relativeTimestamp))
            videoFrameIndex += 1
        }

        guard relativeTimestamp - lastMaskTimestamp >= depthMaskInterval else { return }
        guard let sceneDepth = frame.sceneDepth else { return }
        guard let mask = maskProcessor.makeMask(from: sceneDepth.depthMap) else { return }

        do {
            try maskHandle?.write(contentsOf: Data(mask))
            depthMaskTimestamps.append(FrameTimestamp(index: depthMaskFrameIndex, timestamp: relativeTimestamp))
            depthMaskFrameIndex += 1
            lastMaskTimestamp = relativeTimestamp
        } catch {
            print("depth_mask write failed: \(error)")
        }
    }

    func finishRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        do {
            try maskHandle?.close()
        } catch {
            completion(.failure(error))
            return
        }
        maskHandle = nil

        videoRecorder.stop { [weak self] completedVideoURL in
            guard let self else { return }
            guard let completedVideoURL else {
                completion(.failure(NSError(
                    domain: "RawDataSessionRecorder",
                    code: 1002,
                    userInfo: [NSLocalizedDescriptionKey: "Video writer failed before completion."]
                )))
                return
            }
            do {
                try self.persistJSONArtifacts(finalVideoURL: completedVideoURL)
                let zip = try self.zipRecordingFolder()
                completion(.success(zip))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func persistJSONArtifacts(finalVideoURL: URL) throws {
        guard let timestampsURL, let metadataURL, let baseMetadata else {
            throw NSError(domain: "RawDataSessionRecorder", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Missing output paths"])
        }

        if videoURL != finalVideoURL {
            videoURL = finalVideoURL
        }

        let timestamps = RawTimestamps(videoFrames: videoTimestamps, depthMaskFrames: depthMaskTimestamps)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(timestamps).write(to: timestampsURL)

        let metadata = RawMetadata(
            deviceModel: baseMetadata.deviceModel,
            iosVersion: baseMetadata.iosVersion,
            cameraResolution: baseMetadata.cameraResolution,
            videoFPS: baseMetadata.videoFPS,
            depthMaskFPS: baseMetadata.depthMaskFPS,
            orientation: RawDataUtilities.orientationString(),
            lidarAvailable: baseMetadata.lidarAvailable,
            depthMaskParameters: baseMetadata.depthMaskParameters
        )
        try encoder.encode(metadata).write(to: metadataURL)
    }

    private func zipRecordingFolder() throws -> URL {
        guard let recordingFolderURL, let zipURL else {
            throw NSError(domain: "RawDataSessionRecorder", code: 1004, userInfo: [NSLocalizedDescriptionKey: "Missing recording folder"])
        }

        let fm = FileManager.default
        try? fm.removeItem(at: zipURL)
        let entries = try SimpleZipArchive.allFiles(in: recordingFolderURL)
        try SimpleZipArchive.createArchive(at: zipURL, entries: entries)
        return zipURL
    }
}
