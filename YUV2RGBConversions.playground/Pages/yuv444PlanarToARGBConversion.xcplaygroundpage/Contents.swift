//: [Previous](@previous)

import Foundation
import Accelerate.vImage
/*
 iOS/macOS has no planar support for the following CVPixelBuffer pixel format (OSType)

 kCVPixelFormatType_444YpCbCr8BiPlanarFullRange,
 kCVPixelFormatType_444YpCbCr8BiPlanarVideoRange,
 kCVPixelFormatType_444YpCbCr8Planar, and,
 kCVPixelFormatType_444YpCbCr8PlanarFullRange
 
 are not available for macOS 10.15/iOS 13.0
 
 We have to convert the 3 separate y, u and v planes into a single yuv interleaved plane

 Apple's Accelerate framework supports kvImage444CrYpCb8 (v308) conversion.
 There is also support for kvImage444CbYpCrA8 (v408)

 The raw 444 planar file was created by ffmpeg using the commandline:
 
 ffmpeg -i sunflower.png  -pix_fmt yuv444p -vf "scale=640:640" test444p.yuv

 ffmpeg extracts the data and output 3 planes one after another.
 The first plane consists of luminance data, the 2nd plane chrominance blue data
 and the 3rd plane chrominance red data.
*/

// This function reads the raw 444yuv file and creates 3 vImage_Buffers.
func readYUV444(_ pathname: String, _ width: Int, _ height: Int) -> [vImage_Buffer]?
{
    let file = fopen(pathname, "rb")
    if file == nil {
        perror("Error opening file")
        return nil
    }
    
    // Calculate the size of y, u, and v planes
    let  frameSize = width * height
    let chromaSize = width * height
    
    // Allocate memory for y, u, and v planes
    let yPlane = malloc(frameSize)
    let uPlane = malloc(chromaSize)
    let vPlane = malloc(chromaSize)
    
    if yPlane == nil || uPlane == nil || vPlane == nil {
        perror("Memory allocation failed");
        fclose(file)
        return nil
    }
    
    // Read the y plane
    fread(yPlane, 1, frameSize, file)
    // Read the u plane
    fread(uPlane, 1, chromaSize, file)
    // Read the v plane
    fread(vPlane, 1, chromaSize, file)
    let yBuffer = try! vImage_Buffer(width: width,
                                    height: height,
                                    bitsPerPixel: 8)
    memcpy(yBuffer.data!, yPlane, width*height)
    let cbBuffer = try! vImage_Buffer(width: width,
                                      height: height,
                                      bitsPerPixel: 8)
    memcpy(cbBuffer.data!, uPlane, width*height)
    let crBuffer = try! vImage_Buffer(width: width,
                                      height: height,
                                      bitsPerPixel: 8)
    memcpy(crBuffer.data!, vPlane, width*height)

    return [yBuffer, cbBuffer, crBuffer]
}

guard let pathname = Bundle.main.path(forResource: "test444p",
                                      ofType: "yuv")
else {
    fatalError("File not found")
}

let width = 640
let height = 640

guard let srcBuffers = readYUV444(pathname, width, height)
else {
    fatalError("The array of source buffers is nil")

}
let  yBuffer = srcBuffers[0]
let cbBuffer = srcBuffers[1]
let crBuffer = srcBuffers[2]
var yCbCrBuffer = try! vImage_Buffer(width: width,
                                     height: height,
                                     bitsPerPixel: 8*3)


// All source buffers must have the same dimensions (width and height)
// but their `rowBytes` may be different.
_ = withUnsafePointer(to: crBuffer) {
    (cr: UnsafePointer<vImage_Buffer>) in
    withUnsafePointer(to: yBuffer) {
        (y: UnsafePointer<vImage_Buffer>) in
        withUnsafePointer(to: cbBuffer) {
            (cb: UnsafePointer<vImage_Buffer>) in
            withUnsafePointer(to: yCbCrBuffer) {
                (yCbCr: UnsafePointer<vImage_Buffer>) in

                var srcPlanarBuffers = [Optional(cr), Optional(y), Optional(cb)]
                var destChannels = [
                    yCbCr.pointee.data,
                    yCbCr.pointee.data.advanced(by: MemoryLayout<Pixel_8>.stride),
                    yCbCr.pointee.data.advanced(by: MemoryLayout<Pixel_8>.stride*2)
                ]

                let channelCount = 3

                _ = vImageConvert_PlanarToChunky8(
                    &srcPlanarBuffers,
                    &destChannels,
                    UInt32(channelCount),
                    MemoryLayout<Pixel_8>.stride * channelCount,
                    vImagePixelCount(width),
                    vImagePixelCount(height),
                    yCbCr.pointee.rowBytes,
                    vImage_Flags(kvImageNoFlags))
            }
        }
    }
}

var bufferPtr = yCbCrBuffer.data!.assumingMemoryBound(to: UInt8.self)
for i in 0..<8 {
    print(bufferPtr[i], terminator: " ")
}
print()

// Convert the yCbCr pixels to ARGB
func configureInfo() -> vImage_YpCbCrToARGB
{
    var info = vImage_YpCbCrToARGB()    // filled with zeroes
    
    // video range 8-bit, unclamped
    var pixelRange = vImage_YpCbCrPixelRange(
        Yp_bias: 16,
        CbCr_bias: 128,
        YpRangeMax: 235,
        CbCrRangeMax: 240,
        YpMax: 255,
        YpMin: 0,
        CbCrMax: 255,
        CbCrMin: 1)
    
    // The contents of `info` object is initialised by the call below. It
    // will be used by the function vImageConvert_444CrYpCb8ToARGB8888
    _ = vImageConvert_YpCbCrToARGB_GenerateConversion(
        kvImage_YpCbCrToARGBMatrix_ITU_R_601_4,
        &pixelRange,
        &info,
        kvImage444CrYpCb8,      // vImageYpCbCrType (OSType:v308)
        kvImageARGB8888,        // vImageARGBType
        vImage_Flags(kvImageDoNotTile))
    
    return info
}

var infoYpCbCrToARGB = configureInfo()
var rgbaDestinationBuffer = try! vImage_Buffer(
    width: width,
    height: height,
    bitsPerPixel: 32)
print(rgbaDestinationBuffer)

// Note: the order which is Cr Yp Cb
// Cr Yp Cb will be decoded as R G B A
var error = vImageConvert_444CrYpCb8ToARGB8888(
    &yCbCrBuffer,           // src
    &rgbaDestinationBuffer, // dest
    &infoYpCbCrToARGB,
    [1,2,3,0],              // XRGB -> RGBX
    255,
    vImage_Flags(kvImagePrintDiagnosticsToConsole))

bufferPtr = rgbaDestinationBuffer.data!.assumingMemoryBound(to: UInt8.self)
for i in 0..<8 {
    print(bufferPtr[i], terminator: " ")
}
print()
var cgImageFormat = vImage_CGImageFormat(
    bitsPerComponent: 8,
    bitsPerPixel: 8 * 4,
    colorSpace: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue))!

let cgImage = try! rgbaDestinationBuffer.createCGImage(format: cgImageFormat)

yBuffer.free()
cbBuffer.free()
crBuffer.free()
yCbCrBuffer.free()
rgbaDestinationBuffer.free()
//: [Next](@next)
