import Foundation
import ARKit
import UIKit
import simd

final class CombinedSessionRecorder {

    private let videoRecorder = ARFrameVideoRecorder()
    private let maskProcessor: RawDepthMaskProcessor

    private let depthMaskFPS: Int
    private let depthMaskInterval: TimeInterval
    private let maxSingleZipBytes: UInt64

    private var recordingFolderURL: URL?
    private var rawFolderURL: URL?
    private var skeletonFolderURL: URL?

    private var videoURL: URL?
    private var depthMaskURL: URL?
    private var timestampsURL: URL?
    private var metadataURL: URL?
    private var skeletonJSONURL: URL?

    private var startTimestamp: TimeInterval?
    private var lastMaskTimestamp: TimeInterval = -.greatestFiniteMagnitude

    private var videoTimestamps: [FrameTimestamp] = []
    private var depthMaskTimestamps: [FrameTimestamp] = []
    private var skeletonFrames: [PoseFrame] = []
    private var videoFrameIndex = 0
    private var depthMaskFrameIndex = 0
    private var skeletonFrameIndex = 0

    private var maskHandle: FileHandle?
    private var baseMetadata: RawMetadata?

    init(
        depthMaskFPS: Int = 10,
        maskWidth: Int = 160,
        maskHeight: Int = 120,
        percentile: Float = 0.15,
        deltaMeters: Float = 0.3,
        maxSingleZipBytes: UInt64 = 130 * 1024 * 1024
    ) {
        self.depthMaskFPS = depthMaskFPS
        self.depthMaskInterval = 1.0 / Double(depthMaskFPS)
        self.maskProcessor = RawDepthMaskProcessor(
            width: maskWidth,
            height: maskHeight,
            percentile: percentile,
            deltaMeters: deltaMeters
        )
        self.maxSingleZipBytes = maxSingleZipBytes
    }

    func prepareRecording(cameraResolution: CGSize, videoFPS: Int, lidarAvailable: Bool) throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
        let index = RawDataUtilities.nextRawRecordingIndex(in: tempDir)
        let recordingName = String(format: "recording_%03d", index)

        let recordingFolderURL = tempDir.appendingPathComponent(recordingName, isDirectory: true)
        let rawFolderURL = recordingFolderURL.appendingPathComponent("raw", isDirectory: true)
        let skeletonFolderURL = recordingFolderURL.appendingPathComponent("skeleton", isDirectory: true)

        let videoURL = rawFolderURL.appendingPathComponent("video.mp4")
        let depthMaskURL = rawFolderURL.appendingPathComponent("depth_mask.bin")
        let timestampsURL = rawFolderURL.appendingPathComponent("timestamps.json")
        let metadataURL = rawFolderURL.appendingPathComponent("metadata.json")
        let skeletonJSONURL = skeletonFolderURL.appendingPathComponent("skeleton.json")

        try? fm.removeItem(at: recordingFolderURL)
        try fm.createDirectory(at: rawFolderURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: skeletonFolderURL, withIntermediateDirectories: true)
        fm.createFile(atPath: depthMaskURL.path, contents: nil)

        guard let handle = try? FileHandle(forWritingTo: depthMaskURL) else {
            throw NSError(domain: "CombinedSessionRecorder", code: 3001, userInfo: [NSLocalizedDescriptionKey: "Cannot create depth_mask.bin"])
        }

        self.recordingFolderURL = recordingFolderURL
        self.rawFolderURL = rawFolderURL
        self.skeletonFolderURL = skeletonFolderURL
        self.videoURL = videoURL
        self.depthMaskURL = depthMaskURL
        self.timestampsURL = timestampsURL
        self.metadataURL = metadataURL
        self.skeletonJSONURL = skeletonJSONURL
        self.maskHandle = handle

        self.startTimestamp = nil
        self.lastMaskTimestamp = -.greatestFiniteMagnitude
        self.videoTimestamps.removeAll()
        self.depthMaskTimestamps.removeAll()
        self.skeletonFrames.removeAll()
        self.videoFrameIndex = 0
        self.depthMaskFrameIndex = 0
        self.skeletonFrameIndex = 0

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
                print("Combined video start failed: \(error)")
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
            print("Combined depth mask write failed: \(error)")
        }
    }

    func process(anchors: [ARAnchor], currentFrameTimestamp: TimeInterval?) {
        guard let startTimestamp else { return }
        guard let frameTimestamp = currentFrameTimestamp else { return }
        let relativeTimestamp = max(0, frameTimestamp - startTimestamp)

        for anchor in anchors {
            guard let body = anchor as? ARBodyAnchor else { continue }

            let names = body.skeleton.definition.jointNames
            let transforms = body.skeleton.jointModelTransforms
            let bodyTransform = body.transform

            var worldJoints: [Int: JointPosition] = [:]

            for (i, name) in names.enumerated() {
                guard let idx = JointIndex.arKitNameToIndex[name] else { continue }

                let jointTransform = simd_mul(bodyTransform, transforms[i])
                let p = jointTransform.columns.3
                let world = SIMD3<Float>(p.x, p.y, p.z)
                worldJoints[idx.rawValue] = JointPosition(x: world.x, y: world.y, z: world.z)
            }

            guard !worldJoints.isEmpty else { continue }

            // In combined mode, no wall calibration is performed.
            skeletonFrames.append(
                PoseFrame(
                    frameIndex: skeletonFrameIndex,
                    timestamp: relativeTimestamp,
                    worldJoints: worldJoints,
                    wallJoints: worldJoints
                )
            )
            skeletonFrameIndex += 1
        }
    }

    func finishRecording(completion: @escaping (Result<[URL], Error>) -> Void) {
        do {
            try maskHandle?.close()
        } catch {
            completion(.failure(error))
            return
        }
        maskHandle = nil

        videoRecorder.stop { [weak self] completedVideoURL in
            guard let self else { return }
            guard completedVideoURL != nil else {
                completion(.failure(NSError(
                    domain: "CombinedSessionRecorder",
                    code: 3002,
                    userInfo: [NSLocalizedDescriptionKey: "Video writer failed before completion."]
                )))
                return
            }

            do {
                try self.persistJSONArtifacts()
                let archives = try self.createSizeAwareArchives()
                completion(.success(archives))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func persistJSONArtifacts() throws {
        guard let timestampsURL, let metadataURL, let skeletonJSONURL, let baseMetadata else {
            throw NSError(domain: "CombinedSessionRecorder", code: 3003, userInfo: [NSLocalizedDescriptionKey: "Missing output paths"])
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

        let skeletonPayload = CombinedSkeletonRecording(
            createdAtUnix: Int(Date().timeIntervalSince1970),
            frames: skeletonFrames
        )
        try encoder.encode(skeletonPayload).write(to: skeletonJSONURL)
    }

    private func createSizeAwareArchives() throws -> [URL] {
        guard let recordingFolderURL, let rawFolderURL, let skeletonFolderURL else {
            throw NSError(domain: "CombinedSessionRecorder", code: 3004, userInfo: [NSLocalizedDescriptionKey: "Missing recording folder"])
        }

        let fm = FileManager.default
        let totalBytes = try SimpleZipArchive.directorySize(at: recordingFolderURL)
        let baseName = recordingFolderURL.lastPathComponent
        let parentFolder = recordingFolderURL.deletingLastPathComponent()

        if totalBytes <= maxSingleZipBytes {
            let fullZipURL = parentFolder.appendingPathComponent("\(baseName)_full.zip")
            let entries = try SimpleZipArchive.allFiles(in: recordingFolderURL, prefix: baseName)
            try SimpleZipArchive.createArchive(at: fullZipURL, entries: entries)
            return [fullZipURL]
        }

        let rawZipURL = parentFolder.appendingPathComponent("\(baseName)_raw.zip")
        let skeletonZipURL = parentFolder.appendingPathComponent("\(baseName)_skeleton.zip")
        try? fm.removeItem(at: rawZipURL)
        try? fm.removeItem(at: skeletonZipURL)

        let rawEntries = try SimpleZipArchive.allFiles(in: rawFolderURL, prefix: "raw")
        let skeletonEntries = try SimpleZipArchive.allFiles(in: skeletonFolderURL, prefix: "skeleton")
        try SimpleZipArchive.createArchive(at: rawZipURL, entries: rawEntries)
        try SimpleZipArchive.createArchive(at: skeletonZipURL, entries: skeletonEntries)
        return [rawZipURL, skeletonZipURL]
    }
}
