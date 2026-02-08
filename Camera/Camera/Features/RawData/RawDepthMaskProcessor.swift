import Foundation
import CoreVideo

final class RawDepthMaskProcessor {

    let width: Int
    let height: Int
    let percentile: Float
    let deltaMeters: Float
    let encodingName: String

    init(width: Int = 160, height: Int = 120, percentile: Float = 0.15, deltaMeters: Float = 0.3) {
        self.width = width
        self.height = height
        self.percentile = percentile
        self.deltaMeters = deltaMeters
        self.encodingName = "grayscale8_relative_depth"
    }

    func makeMask(from depthMap: CVPixelBuffer) -> [UInt8]? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return nil
        }

        let srcWidth = CVPixelBufferGetWidth(depthMap)
        let srcHeight = CVPixelBufferGetHeight(depthMap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let rowStride = bytesPerRow / MemoryLayout<Float32>.size
        let pointer = baseAddress.bindMemory(to: Float32.self, capacity: rowStride * srcHeight)

        var downsampled = Array(repeating: Float.greatestFiniteMagnitude, count: width * height)
        var validDepths: [Float] = []
        validDepths.reserveCapacity(width * height)

        for y in 0..<height {
            let srcY = min(srcHeight - 1, y * srcHeight / height)
            for x in 0..<width {
                let srcX = min(srcWidth - 1, x * srcWidth / width)
                let depth = pointer[srcY * rowStride + srcX]
                let idx = y * width + x
                downsampled[idx] = depth
                if depth.isFinite && depth > 0 {
                    validDepths.append(depth)
                }
            }
        }

        guard !validDepths.isEmpty else { return nil }

        validDepths.sort()
        let percentileIndex = max(0, min(validDepths.count - 1, Int(Float(validDepths.count - 1) * percentile)))
        let dMin = validDepths[percentileIndex]
        let threshold = dMin + deltaMeters

        var foreground = Array(repeating: UInt8(0), count: width * height)
        for i in 0..<downsampled.count {
            let depth = downsampled[i]
            if depth.isFinite && depth > 0 && depth < threshold {
                foreground[i] = 1
            }
        }

        // Closing to keep thin limbs connected.
        foreground = dilate(foreground)
        foreground = erode(foreground)

        var fgMin = Float.greatestFiniteMagnitude
        var fgMax: Float = 0
        for i in 0..<downsampled.count where foreground[i] == 1 {
            let depth = downsampled[i]
            guard depth.isFinite && depth > 0 else { continue }
            fgMin = min(fgMin, depth)
            fgMax = max(fgMax, depth)
        }

        // Stretch foreground depth to 1...255 each frame so values are not effectively binary.
        let range = max(1e-4, fgMax - fgMin)
        var mask = Array(repeating: UInt8(0), count: width * height)
        for i in 0..<downsampled.count {
            guard foreground[i] == 1 else { continue }
            let depth = downsampled[i]
            guard depth.isFinite && depth > 0 else { continue }

            let normalized = (depth - fgMin) / range
            let clamped = max(0, min(1, normalized))
            let gray = UInt8(max(1, min(255, Int((1 - clamped) * 254) + 1)))
            mask[i] = gray
        }

        return mask
    }

    private func dilate(_ input: [UInt8]) -> [UInt8] {
        var output = Array(repeating: UInt8(0), count: input.count)
        for y in 0..<height {
            for x in 0..<width {
                var value: UInt8 = 0
                for ky in -1...1 {
                    let yy = y + ky
                    if yy < 0 || yy >= height { continue }
                    for kx in -1...1 {
                        let xx = x + kx
                        if xx < 0 || xx >= width { continue }
                        if input[yy * width + xx] == 1 {
                            value = 1
                            break
                        }
                    }
                    if value == 1 { break }
                }
                output[y * width + x] = value
            }
        }
        return output
    }

    private func erode(_ input: [UInt8]) -> [UInt8] {
        var output = Array(repeating: UInt8(0), count: input.count)
        for y in 0..<height {
            for x in 0..<width {
                var value: UInt8 = 1
                for ky in -1...1 {
                    let yy = y + ky
                    if yy < 0 || yy >= height {
                        value = 0
                        break
                    }
                    for kx in -1...1 {
                        let xx = x + kx
                        if xx < 0 || xx >= width || input[yy * width + xx] == 0 {
                            value = 0
                            break
                        }
                    }
                    if value == 0 { break }
                }
                output[y * width + x] = value
            }
        }
        return output
    }
}
