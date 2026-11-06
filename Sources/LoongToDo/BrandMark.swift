import SwiftUI
import AppKit

/// One vector master for the sidebar, exported artwork, and every Dock icon size.
enum BrandArtwork {
    // Palette C: white tile, midnight-blue ribbon, bright-orange page tip.
    static let surfaceHex = "#FFFFFF"
    static let ribbonHex = "#273651"
    static let foldHex = "#FF984F"
    static let borderHex = "#E7E8ED"
    static let surfaceColor = color(surfaceHex)
    static let ribbonColor = color(ribbonHex)
    static let foldColor = color(foldHex)
    static let borderColor = color(borderHex)

    private static func color(_ hex: String) -> NSColor {
        let value = UInt32(hex.dropFirst(), radix: 16)!
        return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                       green: CGFloat((value >> 8) & 255) / 255,
                       blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    private static func opticallySized(_ path: CGPath) -> CGPath {
        // Enlarge the solid silhouette to reduce whitespace inside the white tile.
        let scale: CGFloat = 1.26
        let inset = 512 * (1 - scale)
        var transform = CGAffineTransform(translationX: inset, y: inset).scaledBy(x: scale, y: scale)
        return path.copy(using: &transform)!
    }

    // The upright of an L flows into a lifted page; coordinates use a 1024pt square.
    static let ribbon: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 294, y: 315))
        path.addCurve(to: CGPoint(x: 340, y: 269), control1: CGPoint(x: 294, y: 289), control2: CGPoint(x: 314, y: 269))
        path.addLine(to: CGPoint(x: 428, y: 269))
        path.addCurve(to: CGPoint(x: 474, y: 315), control1: CGPoint(x: 454, y: 269), control2: CGPoint(x: 474, y: 289))
        path.addLine(to: CGPoint(x: 474, y: 548))
        path.addCurve(to: CGPoint(x: 512, y: 590), control1: CGPoint(x: 474, y: 576), control2: CGPoint(x: 488, y: 590))
        path.addCurve(to: CGPoint(x: 566, y: 565), control1: CGPoint(x: 534, y: 590), control2: CGPoint(x: 548, y: 584))
        path.addLine(to: CGPoint(x: 672, y: 465))
        path.addCurve(to: CGPoint(x: 704, y: 464), control1: CGPoint(x: 681, y: 455), control2: CGPoint(x: 695, y: 455))
        path.addLine(to: CGPoint(x: 771, y: 523))
        path.addCurve(to: CGPoint(x: 773, y: 555), control1: CGPoint(x: 781, y: 532), control2: CGPoint(x: 782, y: 546))
        path.addLine(to: CGPoint(x: 663, y: 672))
        path.addCurve(to: CGPoint(x: 504, y: 747), control1: CGPoint(x: 616, y: 722), control2: CGPoint(x: 564, y: 747))
        path.addCurve(to: CGPoint(x: 294, y: 551), control1: CGPoint(x: 372, y: 747), control2: CGPoint(x: 294, y: 672))
        path.closeSubpath()
        return opticallySized(path)
    }()

    static let fold: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 566, y: 565))
        path.addLine(to: CGPoint(x: 672, y: 465))
        path.addCurve(to: CGPoint(x: 704, y: 464), control1: CGPoint(x: 681, y: 455), control2: CGPoint(x: 695, y: 455))
        path.addLine(to: CGPoint(x: 771, y: 523))
        path.addCurve(to: CGPoint(x: 773, y: 555), control1: CGPoint(x: 781, y: 532), control2: CGPoint(x: 782, y: 546))
        path.addCurve(to: CGPoint(x: 665, y: 598), control1: CGPoint(x: 748, y: 578), control2: CGPoint(x: 709, y: 606))
        path.addCurve(to: CGPoint(x: 566, y: 565), control1: CGPoint(x: 629, y: 592), control2: CGPoint(x: 595, y: 566))
        path.closeSubpath()
        return opticallySized(path)
    }()
}

private struct BrandShape: Shape {
    var folded = false
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 1024
        let transform = CGAffineTransform(translationX: rect.midX - 512 * scale, y: rect.midY - 512 * scale)
            .scaledBy(x: scale, y: scale)
        return Path(folded ? BrandArtwork.fold : BrandArtwork.ribbon).applying(transform)
    }
}

struct BrandLogo: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: proxy.size.width * 0.25, style: .continuous)
                    .fill(Color(nsColor: BrandArtwork.surfaceColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: proxy.size.width * 0.25, style: .continuous)
                            .strokeBorder(Color(nsColor: BrandArtwork.borderColor), lineWidth: 0.5)
                    }
                BrandShape().fill(Color(nsColor: BrandArtwork.ribbonColor))
                BrandShape(folded: true).fill(Color(nsColor: BrandArtwork.foldColor))
            }
        }.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
    }
}
