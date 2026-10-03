import Foundation
import Vision
import CoreGraphics
import CoreVideo

// Offline asset preparation only: segmentation never runs in the desktop app.
let width = 540, height = 540, frameBytes = width * height * 3
let input = FileHandle.standardInput, output = FileHandle.standardOutput
let colorSpace = CGColorSpaceCreateDeviceRGB()
var frameNumber = 0
while true {
    let data = input.readData(ofLength: frameBytes)
    if data.isEmpty { break }
    guard data.count == frameBytes else { fatalError("Incomplete input frame") }
    try autoreleasepool {
        let rgb = [UInt8](data)
        var rgba = [UInt8](repeating: 255, count: width * height * 4)
        for p in 0..<(width * height) {
            rgba[p*4] = rgb[p*3]; rgba[p*4+1] = rgb[p*3+1]; rgba[p*4+2] = rgb[p*3+2]
        }
        let provider = CGDataProvider(data: Data(rgba) as CFData)!
        let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                         bytesPerRow: width*4, space: colorSpace,
                         bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                         provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let handler = VNImageRequestHandler(cgImage: cg)
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            throw NSError(domain: "DobiSegmentation", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Dog not detected at frame \(frameNumber)"])
        }
        let mask = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
        guard CVPixelBufferGetPixelFormatType(mask) == kCVPixelFormatType_OneComponent32Float else {
            fatalError("Unexpected mask format")
        }
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        let stride = CVPixelBufferGetBytesPerRow(mask) / MemoryLayout<Float>.stride
        let values = CVPixelBufferGetBaseAddress(mask)!.assumingMemoryBound(to: Float.self)
        for y in 0..<height { for x in 0..<width {
            let p = y * width + x
            let v = max(0, min(1, values[y*stride+x]))
            let alpha: UInt8 = v < 0.03 ? 0 : (v > 0.97 ? 255 : UInt8(v * 255))
            rgba[p*4+3] = alpha
            if alpha == 0 { rgba[p*4] = 0; rgba[p*4+1] = 0; rgba[p*4+2] = 0 }
        } }
        CVPixelBufferUnlockBaseAddress(mask, .readOnly)
        output.write(Data(rgba))
    }
    frameNumber += 1
}
