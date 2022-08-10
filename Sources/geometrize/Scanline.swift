import Foundation

// Represents a scanline, a row of pixels running across a bitmap.

internal struct Scanline {
    
    // Creates empty useless scanline.
    internal init() {
        y = 0
        x1 = 0
        x2 = 0
    }
    
    // Creates a new scanline.
    // @param y The y-coordinate.
    // @param x1 The leftmost x-coordinate.
    // @param x2 The rightmost x-coordinate.
    internal init(y: Int, x1: Int, x2: Int) {
        self.y = y
        self.x1 = x1
        self.x2 = x2
    }
    
    // The y-coordinate of the scanline.
    internal let y: Int
    
    // The leftmost x-coordinate of the scanline.
    internal let x1: Int
    
    // The rightmost x-coordinate of the scanline.
    internal let x2: Int
}

extension Array where Element == Scanline {

     // Crops the scanning width of an array of scanlines so they do not scan outside of the given area.
     // @param minX The minimum x value to crop to.
     // @param minY The minimum y value to crop to.
     // @param maxX The maximum x value to crop to.
     // @param maxY The maximum y value to crop to.
     // @return A new vector of cropped scanlines.
    func trimmedScanlines(minX: Int, minY: Int, maxX: Int, maxY: Int) -> Self {
        var trimmedScanlines = Self()
        for line in self {
            if line.y < minY || line.y >= maxY {
                continue
            }
            if line.x1 > line.x2 {
                continue
            }
            let x1 = line.x1.clamped(to: minX...maxX - 1)
            let x2 = line.x2.clamped(to: minX...maxX - 1)
            trimmedScanlines.append(Scanline(y: line.y, x1: x1, x2: x2))
        }
        return trimmedScanlines
    }

    // Returns true if the scanlines contain transparent pixels in the given image
    // @param image The image whose pixels to check
    // @param minAlpha The minimum alpha level (0-255) to consider transparent
    // @return True if the scanlines contains any transparent pixels
    func containTransparentPixels(image: Bitmap, minAlpha: UInt8) -> Bool {
        let trimmedScanlines = self.trimmedScanlines(minX: 0, minY: 0, maxX: image.width, maxY: image.height)
        for scanline in trimmedScanlines {
            for x in scanline.x1..<scanline.x2 {
                if image[x, scanline.y].a < minAlpha {
                    return true
                }
            }
        }
        return false
    }

}
