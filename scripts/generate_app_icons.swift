#!/usr/bin/env swift

import AppKit
import Foundation

struct IconVariant {
    let filename: String
    let pixels: Int
}

let variants = [
    IconVariant(filename: "icon_16x16.png", pixels: 16),
    IconVariant(filename: "icon_16x16@2x.png", pixels: 32),
    IconVariant(filename: "icon_32x32.png", pixels: 32),
    IconVariant(filename: "icon_32x32@2x.png", pixels: 64),
    IconVariant(filename: "icon_128x128.png", pixels: 128),
    IconVariant(filename: "icon_128x128@2x.png", pixels: 256),
    IconVariant(filename: "icon_256x256.png", pixels: 256),
    IconVariant(filename: "icon_256x256@2x.png", pixels: 512),
    IconVariant(filename: "icon_512x512.png", pixels: 512),
    IconVariant(filename: "icon_512x512@2x.png", pixels: 1024)
]

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: generate_app_icons.swift INPUT_PNG OUTPUT_APPICONSET\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)

guard let source = NSImage(contentsOf: inputURL) else {
    fputs("Unable to read input image: \(inputURL.path)\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

func renderIcon(size: Int) throws -> Data {
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
        throw CocoaError(.fileWriteUnknown)
    }

    bitmap.size = NSSize(width: size, height: size)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.cgContext.setAllowsAntialiasing(true)
    context.cgContext.setShouldAntialias(true)
    context.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))

    // The generated master intentionally includes a rounded icon tile. This precise mask removes
    // all generative fringe outside that tile while preserving the artwork and transparent corners.
    let dimension = CGFloat(size)
    let inset = dimension * 0.059
    let iconRect = NSRect(x: inset, y: inset, width: dimension - inset * 2, height: dimension - inset * 2)
    let cornerRadius = dimension * 0.19
    NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius).addClip()

    source.draw(
        in: NSRect(x: 0, y: 0, width: dimension, height: dimension),
        from: .zero,
        operation: .copy,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return data
}

for variant in variants {
    let data = try renderIcon(size: variant.pixels)
    try data.write(to: outputURL.appendingPathComponent(variant.filename), options: .atomic)
}

print("Generated \(variants.count) app icon files in \(outputURL.path)")
