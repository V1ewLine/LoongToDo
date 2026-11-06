import AppKit

@main struct IconExport {
    static func main() throws {
        let target = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let brand = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        for directory in [target, brand] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let name = "icon_\(size)x\(size)" + (scale == 2 ? "@2x" : "") + ".png"
                try render(pixels: size * scale).write(to: target.appendingPathComponent(name))
            }
        }
        try render(pixels: 1024).write(to: brand.appendingPathComponent("LoongTodo-icon.png"))
        try render(pixels: 1024, tile: false).write(to: brand.appendingPathComponent("LoongTodo-mark.png"))
        try svg(tile: true).write(to: brand.appendingPathComponent("LoongTodo-icon.svg"), atomically: true, encoding: .utf8)
        try svg(tile: false).write(to: brand.appendingPathComponent("LoongTodo-mark.svg"), atomically: true, encoding: .utf8)
    }

    static func render(pixels: Int, tile: Bool = true) -> Data {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let context = NSGraphicsContext.current!.cgContext
        context.translateBy(x: 0, y: CGFloat(pixels))
        context.scaleBy(x: CGFloat(pixels) / 1024, y: -CGFloat(pixels) / 1024)
        if tile {
            let surface = CGPath(roundedRect: CGRect(x: 80, y: 80, width: 864, height: 864), cornerWidth: 216, cornerHeight: 216, transform: nil)
            if pixels >= 64 {
                context.saveGState()
                context.setShadow(offset: CGSize(width: 0, height: -10), blur: 26, color: NSColor(srgbRed: 37 / 255, green: 43 / 255, blue: 67 / 255, alpha: 0.12).cgColor)
                context.addPath(surface); context.setFillColor(BrandArtwork.surfaceColor.cgColor); context.fillPath()
                context.restoreGState()
            }
            context.addPath(surface); context.setFillColor(BrandArtwork.surfaceColor.cgColor); context.fillPath()
            context.addPath(surface); context.setStrokeColor(BrandArtwork.borderColor.cgColor)
            context.setLineWidth(2); context.strokePath()
            // Inset the same symbol used by the sidebar to the Dock tile bounds.
            context.translateBy(x: 80, y: 80); context.scaleBy(x: 0.84375, y: 0.84375)
        }
        context.addPath(BrandArtwork.ribbon); context.setFillColor(BrandArtwork.ribbonColor.cgColor); context.fillPath()
        // Keep the contrasting tip at every size: it is part of the selected identity.
        context.addPath(BrandArtwork.fold); context.setFillColor(BrandArtwork.foldColor.cgColor); context.fillPath()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])!
    }

    static func svgPath(_ path: CGPath) -> String {
        var commands: [String] = []
        path.applyWithBlock { element in
            let item = element.pointee
            func point(_ index: Int) -> String { "\(Int(item.points[index].x)) \(Int(item.points[index].y))" }
            switch item.type {
            case .moveToPoint: commands.append("M\(point(0))")
            case .addLineToPoint: commands.append("L\(point(0))")
            case .addQuadCurveToPoint: commands.append("Q\(point(0)) \(point(1))")
            case .addCurveToPoint: commands.append("C\(point(0)) \(point(1)) \(point(2))")
            case .closeSubpath: commands.append("Z")
            @unknown default: break
            }
        }
        return commands.joined(separator: " ")
    }

    static func svg(tile: Bool) -> String {
        let surface = tile ? "<rect x=\"80\" y=\"80\" width=\"864\" height=\"864\" rx=\"216\" fill=\"\(BrandArtwork.surfaceHex)\" stroke=\"\(BrandArtwork.borderHex)\" stroke-width=\"2\"/>" : ""
        let transform = tile ? "translate(80 80) scale(.84375)" : ""
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="LoongTodo · 翻页的 L">
          \(surface)
          <g transform="\(transform)">
            <path fill="\(BrandArtwork.ribbonHex)" d="\(svgPath(BrandArtwork.ribbon))"/>
            <path fill="\(BrandArtwork.foldHex)" d="\(svgPath(BrandArtwork.fold))"/>
          </g>
        </svg>
        """
    }
}
