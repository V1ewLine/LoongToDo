import SwiftUI
import AppKit

/// One vector master for the sidebar, exported artwork, and every Dock icon size.
enum BrandArtwork {
    static let topColor = NSColor(srgbRed: 0.57, green: 0.56, blue: 0.88, alpha: 1)
    static let bottomColor = NSColor(srgbRed: 0.25, green: 0.33, blue: 0.70, alpha: 1)

    private static func opticallySized(_ path: CGPath) -> CGPath {
        var transform = CGAffineTransform(translationX: -61.44, y: -61.44).scaledBy(x: 1.12, y: 1.12)
        return path.copy(using: &transform)!
    }

    // The upright of an L flows into a lifted page; coordinates use a 1024pt square.
    static let ribbon: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 294, y: 315))
        path.addCurve(to: CGPoint(x: 340, y: 269), control1: CGPoint(x: 294, y: 289), control2: CGPoint(x: 314, y: 269))
        path.addLine(to: CGPoint(x: 398, y: 269))
        path.addCurve(to: CGPoint(x: 444, y: 315), control1: CGPoint(x: 424, y: 269), control2: CGPoint(x: 444, y: 289))
        path.addLine(to: CGPoint(x: 444, y: 548))
        path.addCurve(to: CGPoint(x: 500, y: 610), control1: CGPoint(x: 444, y: 588), control2: CGPoint(x: 462, y: 610))
        path.addCurve(to: CGPoint(x: 566, y: 577), control1: CGPoint(x: 524, y: 610), control2: CGPoint(x: 544, y: 600))
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
        path.move(to: CGPoint(x: 566, y: 577))
        path.addLine(to: CGPoint(x: 672, y: 465))
        path.addCurve(to: CGPoint(x: 704, y: 464), control1: CGPoint(x: 681, y: 455), control2: CGPoint(x: 695, y: 455))
        path.addLine(to: CGPoint(x: 771, y: 523))
        path.addCurve(to: CGPoint(x: 773, y: 555), control1: CGPoint(x: 781, y: 532), control2: CGPoint(x: 782, y: 546))
        path.addCurve(to: CGPoint(x: 665, y: 598), control1: CGPoint(x: 748, y: 578), control2: CGPoint(x: 709, y: 606))
        path.addCurve(to: CGPoint(x: 566, y: 577), control1: CGPoint(x: 629, y: 592), control2: CGPoint(x: 595, y: 578))
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
                    .fill(LinearGradient(colors: [Color(nsColor: BrandArtwork.topColor), Color(nsColor: BrandArtwork.bottomColor)], startPoint: .topLeading, endPoint: .bottomTrailing))
                BrandShape().fill(.white)
                BrandShape(folded: true)
                    .fill(LinearGradient(colors: [Color(red: 0.91, green: 0.92, blue: 1), Color(red: 0.70, green: 0.77, blue: 0.98)], startPoint: .topTrailing, endPoint: .bottomLeading))
            }
        }.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
    }
}
