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
                context.setShadow(offset: CGSize(width: 0, height: -12), blur: 22, color: NSColor(srgbRed: 0.18, green: 0.21, blue: 0.40, alpha: 0.18).cgColor)
                context.addPath(surface); context.setFillColor(BrandArtwork.bottomColor.cgColor); context.fillPath()
                context.restoreGState()
            }
            gradient(context, in: surface, colors: [BrandArtwork.topColor, BrandArtwork.bottomColor], from: CGPoint(x: 100, y: 80), to: CGPoint(x: 850, y: 944))
            context.addPath(surface); context.setStrokeColor(NSColor.white.withAlphaComponent(0.22).cgColor)
            context.setLineWidth(2); context.strokePath()
            // Inset the same symbol used by the sidebar to the Dock tile bounds.
            context.translateBy(x: 80, y: 80); context.scaleBy(x: 0.84375, y: 0.84375)
        }
        if tile {
            context.saveGState()
            if pixels >= 64 { context.setShadow(offset: CGSize(width: 0, height: -9), blur: 14, color: NSColor(srgbRed: 0.15, green: 0.19, blue: 0.48, alpha: 0.2).cgColor) }
            context.addPath(BrandArtwork.ribbon); context.setFillColor(NSColor.white.cgColor); context.fillPath()
            context.restoreGState()
        } else {
            gradient(context, in: BrandArtwork.ribbon, colors: [BrandArtwork.topColor, BrandArtwork.bottomColor], from: CGPoint(x: 294, y: 269), to: CGPoint(x: 700, y: 747))
        }
        // At 16–32 px the uninterrupted silhouette is more legible than a shaded fold.
        if pixels >= 64 {
            gradient(context, in: BrandArtwork.fold, colors: tile
                ? [NSColor(srgbRed: 0.91, green: 0.92, blue: 1, alpha: 1), NSColor(srgbRed: 0.70, green: 0.77, blue: 0.98, alpha: 1)]
                : [NSColor(srgbRed: 0.70, green: 0.72, blue: 0.96, alpha: 1), BrandArtwork.topColor], from: CGPoint(x: 730, y: 465), to: CGPoint(x: 600, y: 610))
        }
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])!
    }

    static func gradient(_ context: CGContext, in path: CGPath, colors: [NSColor], from start: CGPoint, to end: CGPoint) {
        context.saveGState()
        context.addPath(path); context.clip()
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: nil)!
        context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
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
        let surface = tile ? "<rect x=\"80\" y=\"80\" width=\"864\" height=\"864\" rx=\"216\" fill=\"url(#blue)\"/>" : ""
        let transform = tile ? "translate(80 80) scale(.84375)" : ""
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="LoongTodo · 翻页的 L">
          <defs>
            <linearGradient id="blue" x2=".8" y2="1"><stop stop-color="#918FE0"/><stop offset="1" stop-color="#4054B3"/></linearGradient>
            <linearGradient id="fold" x1="1" x2="0" y2="1"><stop stop-color="\(tile ? "#E8EBFF" : "#B3B8F5")"/><stop offset="1" stop-color="\(tile ? "#B3C4FA" : "#918FE0")"/></linearGradient>
          </defs>
          \(surface)
          <g transform="\(transform)">
            <path fill="\(tile ? "white" : "url(#blue)")" d="\(svgPath(BrandArtwork.ribbon))"/>
            <path fill="url(#fold)" d="\(svgPath(BrandArtwork.fold))"/>
          </g>
        </svg>
        """
    }
}
