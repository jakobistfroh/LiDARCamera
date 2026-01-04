//
//  ARFrameVideoRecorder.swift
//  testen
//
//  Created by Carla Frohwein on 25.12.25.
//

import Foundation
import AVFoundation
import CoreVideo

final class ARFrameVideoRecorder {

    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var didStartSession = false

    private(set) var outputURL: URL?

    var isRecording: Bool {
        writer != nil
    }

    func start(with firstPixelBuffer: CVPixelBuffer) throws {

        let width = CVPixelBufferGetWidth(firstPixelBuffer)
        let height = CVPixelBufferGetHeight(firstPixelBuffer)

        // 👉 Auflösung halbieren (extrem wirksam)
        let targetWidth = width / 2
        let targetHeight = height / 2

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording_\(Int(Date().timeIntervalSince1970)).mp4")
        outputURL = url

        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: targetWidth,
            AVVideoHeightKey: targetHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6_000_000, // ✅ 6 Mbps
                AVVideoExpectedSourceFrameRateKey: 30,
                AVVideoMaxKeyFrameIntervalKey: 30,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: videoSettings
        )
        input.expectsMediaDataInRealTime = true

        let sourceAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String:
                Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
            kCVPixelBufferWidthKey as String: targetWidth,
            kCVPixelBufferHeightKey as String: targetHeight
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourceAttrs
        )

        guard writer!.canAdd(input) else {
            throw NSError(domain: "ARFrameVideoRecorder", code: -1)
        }

        writer!.add(input)
        writer!.startWriting()

        self.input = input
        self.adaptor = adaptor
        self.didStartSession = false

        print("🎥 Frame recorder started: \(url.lastPathComponent) \(targetWidth)x\(targetHeight)")
    }

    func append(pixelBuffer: CVPixelBuffer, timestampSeconds: Double) {
        guard let writer, let input, let adaptor else { return }
        guard writer.status == .writing || writer.status == .unknown else { return }

        let time = CMTime(seconds: timestampSeconds, preferredTimescale: 600)

        if !didStartSession {
            didStartSession = true
            writer.startSession(atSourceTime: time)
        }

        guard input.isReadyForMoreMediaData else { return }
        adaptor.append(pixelBuffer, withPresentationTime: time)
    }

    func stop(completion: @escaping (URL?) -> Void) {
        guard let writer, let input else {
            completion(nil)
            return
        }

        input.markAsFinished()
        writer.finishWriting { [weak self] in
            let url = self?.outputURL

            self?.writer = nil
            self?.input = nil
            self?.adaptor = nil
            self?.didStartSession = false

            print("🎥 Frame recorder stopped: \(url?.lastPathComponent ?? "nil")")
            completion(url)
        }
    }
}
