import Foundation
import ZIPFoundation

struct ZipExporter {

    static func createZip(videoURL: URL, jsonURL: URL) -> URL? {
        let tmp = FileManager.default.temporaryDirectory
        let zipURL = tmp.appendingPathComponent("climb_recording_\(Int(Date().timeIntervalSince1970)).zip")

        // evtl. alte Datei löschen
        try? FileManager.default.removeItem(at: zipURL)

        do {
            guard let archive = Archive(url: zipURL, accessMode: .create) else {
                print("❌ ZIP: konnte Archiv nicht erstellen")
                return nil
            }

            try archive.addEntry(with: "video.mp4", fileURL: videoURL)
            try archive.addEntry(with: "skeleton.json", fileURL: jsonURL)

            print("📦 ZIP erstellt: \(zipURL.path)")
            return zipURL
        } catch {
            print("❌ ZIP Fehler: \(error)")
            return nil
        }
    }
}
