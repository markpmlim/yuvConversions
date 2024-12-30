import Cocoa
/*
 iOS/macOS has planar support for the following CVPixelBuffer pixel format (OSType)
 
 kCVPixelFormatType_420YpCbCr8Planar
 kCVPixelFormatType_420YpCbCr8PlanarFullRange

 The raw 420p yuv file which was created by ffmpeg using the commandline:

 ffmpeg -i sunflower.png  -pix_fmt yuv420p -vf "scale=640:640" test420p.yuv

 ffmpeg extracts the data and output 3 planes one after another.
 The first plane consists of luminance data, the 2nd plane chrominance blue data
 and the 3rd plane chrominance red data
 */

// This function reads a raw 420p yuv file and create a CVPixelBuffer with 3 planes
func readYUV420(_ pathname: String, _ width: Int, _ height: Int) -> CVPixelBuffer?
{
    let file = fopen(pathname, "rb")
    if file == nil {
        perror("Error opening file")
        return nil
    }


    // Calculate the size of y, u, and v planes
    let frameSize = width * height
    // The u and v planes each has half the resolution of the luminance plane
    let chromaSize = frameSize / 4

    // Allocate memory for y, u, and v planes
    let yPlane = malloc(frameSize)
    let uPlane = malloc(chromaSize)
    let vPlane = malloc(chromaSize)

    if yPlane == nil || uPlane == nil || vPlane == nil {
        perror("Memory allocation failed");
        fclose(file)
        return nil
    }

    // Number of bytes read must match the value of framesize or chromaSize
    // Read the y plane
    fread(yPlane, 1, frameSize, file)
    // Read the u plane
    fread(uPlane, 1, chromaSize, file)
    // Read the v plane
    fread(vPlane, 1, chromaSize, file)

    let pixelBufferAttributes = [
        kCVPixelBufferMetalCompatibilityKey as String : true,
        kCVPixelBufferIOSurfacePropertiesKey as String : [String: Any]()
    ] as CFDictionary

    // Create a CVPixelBuffer with 3 planes
    var pixelBuffer: CVPixelBuffer? = nil
    let planes = [yPlane, uPlane, vPlane]
    // kCVPixelFormatType_420YpCbCr8PlanarFullRange or kCVPixelFormatType_420YpCbCr8Planar
    // can be used to create a CVPixelBuffer with 3 planes
    var status = CVPixelBufferCreate(
        nil,
        width, height,
        kCVPixelFormatType_420YpCbCr8PlanarFullRange,
        pixelBufferAttributes,
        &pixelBuffer)

    CVPixelBufferLockBaseAddress(pixelBuffer!, .readOnly)
    // Copy data from the y, u and v planes to the planes of the CVPixelBuffer
    for i in 0..<3 {
        let baseAddr = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer!, i)
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer!, i)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer!, i)
        // Copy all bytes at one go.
        memcpy(baseAddr, planes[i], rowBytes * height)
    }
    status = CVPixelBufferUnlockBaseAddress(pixelBuffer!, .readOnly)

    // Clean up
    free(yPlane)
    free(uPlane)
    free(vPlane)
    fclose(file)

    return pixelBuffer
}

guard let metalDevice = MTLCreateSystemDefaultDevice()
else {
    fatalError("No Metal-capable GPU available")
}

guard let pathname = Bundle.main.path(forResource: "test420p",
                                      ofType: "yuv")
else {
    fatalError("No file found at the specified path")
}

let width = 640
let height = 640

guard let cvPixelBuffer = readYUV420(pathname, width, height)
else {
    fatalError("Failed to produce a CVPixelBuffer object")
}
//print(cvPixelBuffer)

CVPixelBufferLockBaseAddress(cvPixelBuffer, .readOnly)

// Create a partially initialised Metal Texture Descriptor
let textureDescr = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .r8Unorm,
    width: 0, height: 0,        // these will be set later.
    mipmapped: false)
textureDescr.usage = [.shaderRead, .shaderWrite]
textureDescr.storageMode = .managed

var ciImages = [CIImage]()
for planeIndex in 0...2 {
    let textureWidth = CVPixelBufferGetWidthOfPlane(cvPixelBuffer, planeIndex)
    let textureHeight = CVPixelBufferGetHeightOfPlane(cvPixelBuffer, planeIndex)
    textureDescr.width = textureWidth
    textureDescr.height = textureHeight
    let texture = metalDevice.makeTexture(descriptor: textureDescr)
    let baseAddress = CVPixelBufferGetBaseAddressOfPlane(cvPixelBuffer, planeIndex)
    let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(cvPixelBuffer, planeIndex)
    let region = MTLRegionMake2D(0, 0,
                                 textureWidth, textureHeight)
    texture!.replace(region: region,
                     mipmapLevel: 0,
                     withBytes: baseAddress!,
                     bytesPerRow: bytesPerRow)
    let ciImage = CIImage(mtlTexture: texture!, options: nil)
    ciImages.append(ciImage!)
}

// This should display an instance of CIImage with a MTLPixelFormat of .r8Unorm
ciImages[0]
ciImages[1]
ciImages[2]

CVPixelBufferUnlockBaseAddress(cvPixelBuffer, .readOnly)

// It is a straighforward process to combine the 3 planes of the CVPixelBuffer object
// into a single destination CGImage.
//: [Next](@next)
