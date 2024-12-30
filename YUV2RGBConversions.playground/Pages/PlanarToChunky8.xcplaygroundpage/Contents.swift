//: [Previous](@previous)
/*
 This source code was modified to run on macOS 10.15 from Apple's online document for the
 function `vImageConvert_PlanarToChunky8`
 */
import Cocoa
import Accelerate.vImage

let width = 4
let height = 1
let cbBuffer = try! vImage_Buffer(width: width,
                                  height: height,
                                  bitsPerPixel: 8)
var bytes: [UInt8] = [10, 11, 12, 13]
memcpy(cbBuffer.data!, bytes, 4)
let crBuffer = try! vImage_Buffer(width: width,
                                  height: height,
                                  bitsPerPixel: 8)
bytes = [20, 21, 22, 23]
memcpy(crBuffer.data!, bytes, 4)

let cbCrBuffer = try! vImage_Buffer(width: width,
                                    height: height,
                                    bitsPerPixel: 8*2)
// The `size` property is only declared under XCode 11.x interface
print(cbCrBuffer.size)

_ = withUnsafePointer(to: cbBuffer) {
    (cb: UnsafePointer<vImage_Buffer>) in
        withUnsafePointer(to: crBuffer) {
            (cr: UnsafePointer<vImage_Buffer>) in
            withUnsafePointer(to: cbCrBuffer) {
                (cbcr: UnsafePointer<vImage_Buffer>) in

            var srcPlanarBuffers = [Optional(cb), Optional(cr)]
            var destChannels = [
                cbcr.pointee.data,
                cbcr.pointee.data.advanced(by: MemoryLayout<Pixel_8>.stride)
            ]
            
            let channelCount = 2
            
            _ = vImageConvert_PlanarToChunky8(
                &srcPlanarBuffers,
                &destChannels,
                UInt32(channelCount),
                MemoryLayout<Pixel_8>.stride * channelCount,
                vImagePixelCount(width),
                vImagePixelCount(height),
                cbcr.pointee.rowBytes,
                vImage_Flags(kvImageNoFlags))
            
        }
    }
}
let bufferPtr = cbCrBuffer.data!.assumingMemoryBound(to: UInt8.self)
for i in 0..<8 {
    print(bufferPtr[i], terminator: " ")
}
print()

/* Original Code
let cbBuffer = vImage.PixelBuffer(pixelValues: [10, 11, 12, 13],
                                  size: size,
                                  pixelFormat: vImage.Planar8.self)


let crBuffer = vImage.PixelBuffer(pixelValues: [20, 21, 22, 23],
                                  size: size,
                                  pixelFormat: vImage.Planar8.self)


let cbCrBuffer = vImage.PixelBuffer(size: size,
                                    pixelFormat: vImage.Interleaved8x2.self)


cbBuffer.withUnsafePointerToVImageBuffer { cb in
    crBuffer.withUnsafePointerToVImageBuffer { cr in
        cbCrBuffer.withUnsafeVImageBuffer { cbcr in
            
            var srcPlanarBuffers = [Optional(cb), Optional(cr)]
            var destChannels = [
                cbcr.data,
                cbcr.data.advanced(by: MemoryLayout<Pixel_8>.stride)
            ]
            
            let channelCount = 2
            
            _ = vImageConvert_PlanarToChunky8(
                &srcPlanarBuffers,
                &destChannels,
                UInt32(channelCount),
                MemoryLayout<Pixel_8>.stride * channelCount,
                vImagePixelCount(width),
                vImagePixelCount(height),
                cbcr.rowBytes,
                vImage_Flags(kvImageNoFlags))
            
        }
    }
}


// Prints "[10, 20,   11, 21,   12, 22,   13, 23]".
print(cbCrBuffer.array)
*/
//: [Next](@next)
