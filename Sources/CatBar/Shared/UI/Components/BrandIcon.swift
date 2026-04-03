import AppKit
import ImageIO

@MainActor
enum BrandIcon {
    private static let logoRelativePaths = [
        "Assets.xcassets/BrandLogo.imageset/logo.png",
        "Resources/Assets.xcassets/BrandLogo.imageset/logo.png",
    ]
    private static let runRelativePaths = [
        "Assets.xcassets/BrandRun.imageset/icon-run.png",
        "Resources/Assets.xcassets/BrandRun.imageset/icon-run.png",
    ]
    private static let sleepRelativePaths = [
        "Assets.xcassets/BrandSleep.imageset/icon-sleep.png",
        "Resources/Assets.xcassets/BrandSleep.imageset/icon-sleep.png",
    ]

    static let image: NSImage? = loadImage(relativePaths: logoRelativePaths, maxPixelDimension: 128)
    static let panelImage: NSImage? = loadImage(relativePaths: logoRelativePaths, maxPixelDimension: 64)
    static let runImage: NSImage? = loadImage(relativePaths: runRelativePaths, maxPixelDimension: 72)
    static let sleepImage: NSImage? = loadImage(relativePaths: sleepRelativePaths, maxPixelDimension: 72)

    private static func loadImage(relativePaths: [String], maxPixelDimension: Int) -> NSImage? {
        for bundle in AppResourceBundleLocator.candidateBundles() {
            for relativePath in relativePaths {
                let url = bundle.bundleURL.appendingPathComponent(relativePath, isDirectory: false)
                if let image = loadDownsampledImage(from: url, maxPixelDimension: maxPixelDimension) {
                    return image
                }
            }
        }
        return nil
    }

    // Decode at the display size we actually need. Loading the original bitmap
    // (for example a 2048px PNG used in a 40px slot) can inflate memory
    // substantially because AppKit/CoreGraphics may keep large decoded caches.
    private static func loadDownsampledImage(from url: URL, maxPixelDimension: Int) -> NSImage? {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: false,
                kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelDimension),
            ] as CFDictionary)
        else {
            return NSImage(contentsOf: url)
        }

        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
