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
    private var lastPresentationTime = CMTime.invalid

    private(set) var outputURL: URL?

    var isRecording: Bool {
        writer != nil
    }

    func start(with firstPixelBuffer: CVPixelBuffer, outputURL customOutputURL: URL? = nil) throws {

        let width = CVPixelBufferGetWidth(firstPixelBuffer)
        let height = CVPixelBufferGetHeight(firstPixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(firstPixelBuffer)

        // Keep source dimensions to avoid pixel-buffer size mismatch on append.
        let targetWidth = width
        let targetHeight = height

        let url = customOutputURL ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("recording_\(Int(Date().timeIntervalSince1970)).mp4")
        outputURL = url

        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: targetWidth,
            AVVideoHeightKey: targetHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 6_000_000,
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
                Int(pixelFormat),
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
        self.lastPresentationTime = CMTime.invalid

        print("Frame recorder started: \(url.lastPathComponent) \(targetWidth)x\(targetHeight), pf=\(pixelFormat)")
    }

    @discardableResult
    func append(pixelBuffer: CVPixelBuffer, timestampSeconds: Double) -> Bool {
        guard let writer, let input, let adaptor else { return false }
        guard writer.status == .writing || writer.status == .unknown else {
            print("Append skipped, writer status: \(writer.status.rawValue), error: \(writer.error?.localizedDescription ?? "nil")")
            return false
        }

        var time = CMTime(seconds: max(0, timestampSeconds), preferredTimescale: 600)
        if lastPresentationTime.isValid && CMTimeCompare(time, lastPresentationTime) <= 0 {
            time = CMTimeAdd(lastPresentationTime, CMTime(value: 1, timescale: 600))
        }

        if !didStartSession {
            didStartSession = true
            writer.startSession(atSourceTime: time)
        }

        guard input.isReadyForMoreMediaData else { return }
        let success = adaptor.append(pixelBuffer, withPresentationTime: time)
        if !success {
            print("Frame append failed, writer status: \(writer.status.rawValue), error: \(writer.error?.localizedDescription ?? "nil")")
            return false
        }
        lastPresentationTime = time
        return true
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
            self?.lastPresentationTime = CMTime.invalid

            let status = writer.status
            let errorText = writer.error?.localizedDescription ?? "nil"
            print("Frame recorder stopped: \(url?.lastPathComponent ?? "nil"), status=\(status.rawValue), error=\(errorText)")
            completion(status == .completed ? url : nil)
        }
    }
}
