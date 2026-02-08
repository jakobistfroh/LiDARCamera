import Foundation
import ARKit
import UIKit

final class RawDataSessionRecorder {

    private let videoRecorder = ARFrameVideoRecorder()
    private let maskProcessor: RawDepthMaskProcessor

    private let depthMaskFPS: Int
    private let depthMaskInterval: TimeInterval

    private var recordingFolderURL: URL?
    private var recordingName: String?
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
    private var targetVideoFPS = 30
    private var targetVideoBitRate = 12_000_000
    private let depthProcessingQueue = DispatchQueue(label: "raw.depth.processing.queue", qos: .utility)

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
        let index = RawDataUtilities.nextRecordingIndex(mode: "raw", in: tempDir)
        let folderName = RawDataUtilities.recordingName(mode: "raw", index: index)

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
        self.recordingName = folderName
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
        self.targetVideoFPS = 30
        self.targetVideoBitRate = 12_000_000

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
            videoFPS: targetVideoFPS,
            depthMaskFPS: depthMaskFPS,
            depthMaskEncoding: maskProcessor.encodingName,
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
                try videoRecorder.start(
                    with: frame.capturedImage,
                    outputURL: videoURL,
                    targetFrameRate: targetVideoFPS,
                    averageBitRate: targetVideoBitRate
                )
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
        let depthData = frame.sceneDepth ?? frame.smoothedSceneDepth
        guard let depthData else { return }
        lastMaskTimestamp = relativeTimestamp

        guard let depthMapCopy = copyDepthMap(depthData.depthMap) else { return }

        depthProcessingQueue.async { [weak self] in
            guard let self else { return }
            guard let mask = self.maskProcessor.makeMask(from: depthMapCopy) else { return }
            do {
                try self.maskHandle?.write(contentsOf: Data(mask))
                self.depthMaskTimestamps.append(
                    FrameTimestamp(index: self.depthMaskFrameIndex, timestamp: relativeTimestamp)
                )
                self.depthMaskFrameIndex += 1
            } catch {
                print("depth_mask write failed: \(error)")
            }
        }
    }

    func finishRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        depthProcessingQueue.sync {}

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
            depthMaskEncoding: baseMetadata.depthMaskEncoding,
            orientation: RawDataUtilities.orientationString(),
            lidarAvailable: baseMetadata.lidarAvailable,
            depthMaskParameters: baseMetadata.depthMaskParameters
        )
        try encoder.encode(metadata).write(to: metadataURL)
    }

    private func zipRecordingFolder() throws -> URL {
        guard let recordingFolderURL, let recordingName, let zipURL else {
            throw NSError(domain: "RawDataSessionRecorder", code: 1004, userInfo: [NSLocalizedDescriptionKey: "Missing recording folder"])
        }

        let fm = FileManager.default
        try? fm.removeItem(at: zipURL)
        let entries = try SimpleZipArchive.allFiles(in: recordingFolderURL, prefix: recordingName)
        try SimpleZipArchive.createArchive(at: zipURL, entries: entries)
        return zipURL
    }

    private func copyDepthMap(_ source: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        let pixelFormat = CVPixelBufferGetPixelFormatType(source)

        var destination: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormat,
            nil,
            &destination
        )
        guard status == kCVReturnSuccess, let destination else { return nil }

        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(destination, [])
        defer {
            CVPixelBufferUnlockBaseAddress(destination, [])
            CVPixelBufferUnlockBaseAddress(source, .readOnly)
        }

        guard
            let srcBase = CVPixelBufferGetBaseAddress(source),
            let dstBase = CVPixelBufferGetBaseAddress(destination)
        else {
            return nil
        }

        let srcBytesPerRow = CVPixelBufferGetBytesPerRow(source)
        let dstBytesPerRow = CVPixelBufferGetBytesPerRow(destination)
        let bytesPerRow = min(srcBytesPerRow, dstBytesPerRow)

        for row in 0..<height {
            let srcPtr = srcBase.advanced(by: row * srcBytesPerRow)
            let dstPtr = dstBase.advanced(by: row * dstBytesPerRow)
            memcpy(dstPtr, srcPtr, bytesPerRow)
        }

        return destination
    }
}
