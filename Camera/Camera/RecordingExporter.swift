import Foundation
import ZIPFoundation

struct RecordingExporter {

    static func export(frames: [PoseFrame], videoURL: URL?) throws -> URL {

        let fm = FileManager.default

        let exportFolder = fm.temporaryDirectory
            .appendingPathComponent("export_\(Int(Date().timeIntervalSince1970))", isDirectory: true)
        try fm.createDirectory(at: exportFolder, withIntermediateDirectories: true)

        var videoFileName: String?
        if let videoURL {
            videoFileName = "recording.mp4"
            let targetVideoURL = exportFolder.appendingPathComponent("recording.mp4")
            try? fm.removeItem(at: targetVideoURL)
            try fm.copyItem(at: videoURL, to: targetVideoURL)
        }

        let recording = PoseRecording(
            createdAtUnix: Int(Date().timeIntervalSince1970),
            videoFileName: videoFileName,
            frames: frames
        )

        let jsonURL = exportFolder.appendingPathComponent("recording.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let jsonData = try encoder.encode(recording)
        try jsonData.write(to: jsonURL)

        let zipURL = fm.temporaryDirectory
            .appendingPathComponent("recording_export_\(Int(Date().timeIntervalSince1970)).zip")
        try? fm.removeItem(at: zipURL)

        let archive = try Archive(url: zipURL, accessMode: .create)
        try archive.addEntry(with: "recording.json", fileURL: jsonURL)

        if let videoFileName {
            let targetVideoURL = exportFolder.appendingPathComponent(videoFileName)
            try archive.addEntry(with: videoFileName, fileURL: targetVideoURL)
        }

        print("ZIP erstellt: \(zipURL.path)")
        return zipURL
    }
}
