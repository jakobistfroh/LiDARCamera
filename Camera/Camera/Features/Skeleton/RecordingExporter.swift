import Foundation

struct RecordingExporter {

    static func export(frames: [PoseFrame], videoURL: URL?) throws -> URL {

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
        let index = RawDataUtilities.nextRecordingIndex(mode: "skeleton", in: tempDir)
        let recordingName = RawDataUtilities.recordingName(mode: "skeleton", index: index)

        let exportFolder = tempDir
            .appendingPathComponent(recordingName, isDirectory: true)
        try? fm.removeItem(at: exportFolder)
        try fm.createDirectory(at: exportFolder, withIntermediateDirectories: true)

        var videoFileName: String?
        if let videoURL {
            videoFileName = "video.mp4"
            let targetVideoURL = exportFolder.appendingPathComponent(videoFileName ?? "video.mp4")
            try? fm.removeItem(at: targetVideoURL)
            try fm.copyItem(at: videoURL, to: targetVideoURL)
        }

        let recording = PoseRecording(
            createdAtUnix: Int(Date().timeIntervalSince1970),
            videoFileName: videoFileName,
            frames: frames
        )

        let jsonURL = exportFolder.appendingPathComponent("skeleton.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let jsonData = try encoder.encode(recording)
        try jsonData.write(to: jsonURL)

        let zipURL = tempDir
            .appendingPathComponent("\(recordingName).zip")
        try? fm.removeItem(at: zipURL)

        var entries: [SimpleZipArchive.Entry] = [
            .init(fileURL: jsonURL, archivePath: "\(recordingName)/skeleton.json")
        ]
        if let videoFileName {
            let targetVideoURL = exportFolder.appendingPathComponent(videoFileName)
            entries.append(.init(fileURL: targetVideoURL, archivePath: "\(recordingName)/\(videoFileName)"))
        }
        try SimpleZipArchive.createArchive(at: zipURL, entries: entries)

        print("ZIP erstellt: \(zipURL.path)")
        return zipURL
    }
}
