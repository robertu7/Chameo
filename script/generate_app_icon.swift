#!/usr/bin/env swift

import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetsURL = rootURL.appendingPathComponent("Assets", isDirectory: true)
let sourceURL = assetsURL.appendingPathComponent("AppIconSource.png")
let iconsetURL = assetsURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let iconURL = assetsURL.appendingPathComponent("AppIcon.icns")

struct IconImage {
    let size: Int
    let scale: Int

    var points: Int { size / scale }

    var filename: String {
        scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@\(scale)x.png"
    }
}

let images = [
    IconImage(size: 16, scale: 1),
    IconImage(size: 32, scale: 2),
    IconImage(size: 32, scale: 1),
    IconImage(size: 64, scale: 2),
    IconImage(size: 128, scale: 1),
    IconImage(size: 256, scale: 2),
    IconImage(size: 256, scale: 1),
    IconImage(size: 512, scale: 2),
    IconImage(size: 512, scale: 1),
    IconImage(size: 1024, scale: 2)
]

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    throw NSError(domain: "IconGeneration", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "Could not load \(sourceURL.path)"
    ])
}

try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func resizedPNG(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "IconGeneration", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Could not allocate \(size)x\(size) bitmap"
        ])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high

    sourceImage.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: .zero,
        operation: .copy,
        fraction: 1
    )

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "Could not encode \(size)x\(size) PNG"
        ])
    }

    return data
}

for image in images {
    try resizedPNG(size: image.size).write(to: iconsetURL.appendingPathComponent(image.filename))
}

try? FileManager.default.removeItem(at: iconURL)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", iconURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(domain: "IconGeneration", code: Int(process.terminationStatus), userInfo: [
        NSLocalizedDescriptionKey: "iconutil failed"
    ])
}

print(iconURL.path)
