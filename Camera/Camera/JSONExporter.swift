import Foundation

struct JSONExporter {

    static func save(frames: [PoseFrame]) -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]

        let data = try! encoder.encode(frames)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("skeleton_\(Int(Date().timeIntervalSince1970)).json")

        try! data.write(to: url)

        print("💾 JSON gespeichert: \(url.path)")
        return url
    }
}
