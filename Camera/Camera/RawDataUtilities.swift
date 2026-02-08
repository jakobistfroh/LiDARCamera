import Foundation
import UIKit

enum RawDataUtilities {

    static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
    }

    static func orientationString() -> String {
        switch UIDevice.current.orientation {
        case .portrait: return "portrait"
        case .portraitUpsideDown: return "portraitUpsideDown"
        case .landscapeLeft: return "landscapeLeft"
        case .landscapeRight: return "landscapeRight"
        case .faceUp: return "faceUp"
        case .faceDown: return "faceDown"
        default: return "unknown"
        }
    }

    static func nextRawRecordingIndex(in directory: URL) -> Int {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return 1
        }
        let regex = try? NSRegularExpression(pattern: #"recording_raw_(\d{3})\.zip"#)
        let indices = items.compactMap { url -> Int? in
            let name = url.lastPathComponent
            let range = NSRange(name.startIndex..<name.endIndex, in: name)
            guard let match = regex?.firstMatch(in: name, options: [], range: range),
                  let idxRange = Range(match.range(at: 1), in: name) else {
                return nil
            }
            return Int(name[idxRange])
        }
        return (indices.max() ?? 0) + 1
    }
}
