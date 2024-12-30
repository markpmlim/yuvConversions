//: [Previous](@previous)
import Cocoa
import CoreVideo
import Accelerate.vImage

/*
 Reads a raw 422 yuv file which was created by `ffmpeg` using the commandline:

    ffmpeg -i sunflower.png  -pix_fmt yuyv422 -vf "scale=640:640" testyuyv422.yuv

 The demo will convert a chunk of 422CbYpCrYp to 2 ARGB pixels, each chunk of 422CbYpCrYp is
 two horizontally adjacent pixels.

 Yp0 Cb0 Yp1 Cr0  will be decoded as A0 R0 G0 B0  A1 R1 G1 B1

 In other words, each row of yCbCr is half the size of a row of decoded ARGB pixels.

 The code can be modified to work for uyvy422 formatted files. Use kvImage422CbYpCrYp8 (2vuy)
 as vImageYpCbCrType.
 */

//  Read a raw 422 yuyv file and returns a vImage_Buffer object.
func readYUV422(_ pathname: String, _ width: Int, _ height: Int) -> vImage_Buffer?
{
    let file = fopen(pathname, "rb")
    if file == nil {
        perror("Error opening file")
        return nil
    }
    
    // Calculate the size of the frame.
    // Total size of ARGB pixels will be width * height * 4 since each of the 4 channels
    // is 8 bits (1 byte).
    // Two 8-bit ARGB pixels will be converted from one 422YpCbYpCr chunk.
    // So the memory size of a 422YpCbYpCr chunk is half that of two 8-bit ARGB pixels.
    let frameSize = width * height * 2
    
    // Allocate memory for the frame
    let readBuffer = malloc(frameSize)

    if readBuffer == nil {
        perror("Memory allocation failed");
        fclose(file)
        return nil
    }
    
    // Read the frame
    fread(readBuffer, 1, frameSize, file)

    let buffer = vImage_Buffer(
        data: readBuffer,
        height: vImagePixelCount(height),
        width: vImagePixelCount(width),
        rowBytes: width*2)

    return buffer
}

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
    // will be used by the function vImageConvert_422YpCbYpCr8ToARGB8888
    // For kvImage422CbYpCrYp8 (2vuy), use vImageConvert_422CbYpCrYp8ToARGB8888
    _ = vImageConvert_YpCbCrToARGB_GenerateConversion(
        kvImage_YpCbCrToARGBMatrix_ITU_R_709_2,
        &pixelRange,
        &info,
        kvImage422YpCbYpCr8,    // vImageYpCbCrType (OSType: yuvs/yuvf)
        kvImageARGB8888,        // vImageARGBType
        vImage_Flags(kvImageDoNotTile))

    return info
}

guard let pathname = Bundle.main.path(forResource: "testyuyv422",
                                      ofType: "yuv")
else {
    fatalError("File not found")
}

let width = 640
let height = 640
guard var sourceBuffer = readYUV422(pathname, width, height)
else {
    fatalError("source buffer is nil")
}

var destinationBuffer = try! vImage_Buffer(
    width: 640, height: 640, bitsPerPixel: 32
)

var yuvInfo = configureInfo()
let status = vImageConvert_422YpCbYpCr8ToARGB8888(
    &sourceBuffer,
    &destinationBuffer,
    &yuvInfo,
    [1,2,3,0],          // XRGB --> RGBX
    255,
    vImage_Flags(0)
)

let bufferPtr = destinationBuffer.data.assumingMemoryBound(to: UInt8.self)
for i in 0 ..< 2 * 4 {
    print(String(format: "0x%02X", bufferPtr[i]), terminator: " ")
}
print()

var cgImageFormat = vImage_CGImageFormat(
    bitsPerComponent: 8,
    bitsPerPixel: 32,
    colorSpace: nil,
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
    version: 0,
    decode: nil,
    renderingIntent: .defaultIntent)

var error = kvImageNoError
// Old function
let cgImage = vImageCreateCGImageFromBuffer(
    &destinationBuffer,
    &cgImageFormat,
    nil,
    nil,
    vImage_Flags(kvImageNoFlags),
    &error).takeRetainedValue()
print(cgImage.bitmapInfo)       // RGBX (noneSkipLast)

// macOS 10.15 or later
let cgImage2 = try destinationBuffer.createCGImage(format: cgImageFormat)

sourceBuffer.free()
destinationBuffer.free()

//: [Next](@next)
