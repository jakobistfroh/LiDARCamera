import ReplayKit
import UIKit

final class ScreenRecorder {

    static let shared = ScreenRecorder()
    private let recorder = RPScreenRecorder.shared()

    private init() {}

    func startRecording() {
        guard !recorder.isRecording else {
            print("ℹ️ ReplayKit: läuft schon.")
            return
        }

        recorder.isMicrophoneEnabled = false

        recorder.startRecording { error in
            if let error = error {
                print("❌ ReplayKit Start-Fehler: \(error.localizedDescription)")
            } else {
                print("🎥 ReplayKit: Aufnahme gestartet")
            }
        }
    }

    /// Stoppt die Aufnahme und liefert eine URL zu einer MP4-Datei im temporären Verzeichnis.
    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard recorder.isRecording else {
            print("ℹ️ ReplayKit: war nicht am Aufnehmen.")
            completion(nil)
            return
        }

        // Ziel-Datei (temp)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording_\(Int(Date().timeIntervalSince1970)).mp4")

        recorder.stopRecording(withOutput: tempURL) { error in
            if let error = error {
                print("❌ ReplayKit Stop-Fehler: \(error.localizedDescription)")
                completion(nil)
                return
            }

            print("📹 ReplayKit: Video geschrieben nach \(tempURL.path)")
            completion(tempURL)
        }
    }
}
