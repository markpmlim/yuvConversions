## Processing raw yuv files

This XCode playground shows how to process files produced by *ffmpeg* using Apple's Accelerate and Metal frameworks. Since the files generated consists of raw pixel data, there is no information about the width and height of the original image/frame. We could name a file as *test420p_640x640.yuv* instead of *test420p.yuv*.

There is direct support  for  raw 420 planar files produced by *ffmpeg*. A triplanar CVPixelBuffer object can be created. This CVPixelBuffer object can be passed as a parameter to functions for further processing.

There is no support for  4:2:2 or 4:4:4  planar CVPixelBuffer objects on macOS/iOS. However, there is a function named

    vImageConvert_PlanarToChunky8

which can be used to convert a set of planar source vImage_Buffers to a single interleaved destination vImage_Buffer.

There is also support for 4:2:2: yuyv or 4:2:2 uyvy raw files produced by *ffmpeg*. The interleaved data from such files can be imported directly into vImage_Buffer objects.

One can also instantiate texture objects from the raw yuv files (planar and non-planar), pass them to a Metal kernel function (or in the case of OpenGL a pair of vertex-fragment shaders) for processing.

How about playing a movie encoded in yuv format since each frame is basically an image?

<br />
<br />

**ffmpeg** supports a variety of multimedia formats. The yuv files used by the demos of this playground is a tiny set of the pixel formats transcoded by *ffmpeg*.

<br />
<br />

**Development Platform:**

XCode 11.6, macOS 10.15

<br />
<br />

**Weblinks:**

https://yuvviewer.com/

https://developer.apple.com/documentation/accelerate/1533042-vimageconvert_planartochunky8

https://en.wikipedia.org/wiki/FFmpeg
