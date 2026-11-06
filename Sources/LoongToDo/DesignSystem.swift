import SwiftUI

enum Style {
    static let accent = adaptive(0x273651, 0xE2EAF6)
    static let accentFill = Color(nsColor: BrandArtwork.ribbonColor)
    static let accentSoft = adaptive(0x687B96, 0x9AACC5)
    static let orangeFill = Color(nsColor: BrandArtwork.foldColor)
    static let orange = adaptive(0xA84C0B, 0xFFB47F)
    static let orangeTint = adaptive(0xFFF0E3, 0x3D2F29)
    static let ink = accent
    static let canvas = adaptive(0xF5F6F8, 0x141C29)
    static let surface = adaptive(0xFFFFFF, 0x202B3D)
    static let surfaceMuted = adaptive(0xF1F3F6, 0x29364A)
    static let border = adaptive(0xE4E8EE, 0x3B485D)

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
}

enum Motion {
    static let press = Animation.spring(response: 0.20, dampingFraction: 0.76)
    static let release = Animation.spring(response: 0.36, dampingFraction: 0.62)
    static let layout = Animation.spring(response: 0.38, dampingFraction: 0.84)
    static let hover = Animation.spring(response: 0.28, dampingFraction: 0.82)

    static func insertion(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .offset(y: 12).combined(with: .scale(scale: 0.94)).combined(with: .opacity)
    }
}

struct AuroraBackground: View {
    var body: some View {
        Style.canvas.ignoresSafeArea().allowsHitTesting(false)
    }
}

struct GlassSurface: ViewModifier {
    var radius: CGFloat = 22
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Style.surface)
                    .shadow(color: .black.opacity(0.025), radius: 8, x: 0, y: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Style.border, lineWidth: 1).allowsHitTesting(false)
            }
    }
}

extension View {
    func glassPanel(radius: CGFloat = 22) -> some View { modifier(GlassSurface(radius: radius)) }
    func floatingCard(radius: CGFloat = 22) -> some View { modifier(FloatingCard(radius: radius)) }
    func liquidControl() -> some View { self.glassPanel(radius: 30) }
}

struct SoftButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 18).padding(.vertical, 12)
            .foregroundStyle(prominent ? Color.white : Style.ink)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(prominent ? Style.accentFill : Style.surface)
                    .shadow(color: .black.opacity(prominent && enabled ? 0.10 : 0), radius: 6, x: 0, y: 3)
            }
            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(prominent ? Color.clear : Style.border))
            .opacity(enabled ? 1 : 0.4)
            .modifier(SpringInteraction(isPressed: configuration.isPressed, pressedScale: 0.95, hoverScale: 1.02))
    }
}

/// Shared by small controls and navigation; disabled and reduced-motion states stay still.
struct ElasticButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.90
    var hoverScale: CGFloat = 1.04
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .modifier(SpringInteraction(isPressed: configuration.isPressed, pressedScale: pressedScale, hoverScale: hoverScale))
    }
}

private struct SpringInteraction: ViewModifier {
    let isPressed: Bool
    let pressedScale: CGFloat
    let hoverScale: CGFloat
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: scale, y: reduceMotion || !enabled ? 1 : isPressed ? pressedScale * 0.96 : hovered ? hoverScale : 1)
            .offset(y: !reduceMotion && enabled && hovered && !isPressed ? -1 : 0)
            .animation(reduceMotion ? nil : isPressed ? Motion.press : Motion.release, value: isPressed)
            .animation(reduceMotion ? nil : Motion.hover, value: hovered)
            .onHover { hovered = $0 }
    }

    private var scale: CGFloat { reduceMotion || !enabled ? 1 : isPressed ? pressedScale : hovered ? hoverScale : 1 }
}

private struct FloatingCard: ViewModifier {
    let radius: CGFloat
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.glassPanel(radius: radius)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Style.accentSoft.opacity(hovered ? 0.35 : 0), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .offset(y: hovered && !reduceMotion ? -2 : 0)
            .animation(reduceMotion ? nil : Motion.hover, value: hovered)
            .onHover { hovered = $0 }
    }
}

struct SmallTag: View {
    let text: String
    var icon: String = ""
    var color: Color = .secondary
    var body: some View {
        HStack(spacing: 4) {
            if !icon.isEmpty { Image(systemName: icon).font(.system(size: 10)) }
            Text(text).font(.system(size: 11, weight: .medium))
        }.foregroundStyle(color).padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.075), in: Capsule())
    }
}

@MainActor enum DateText {
    private static var formatters: [String: DateFormatter] = [:]
    static func string(_ date: Date, _ format: String) -> String {
        let formatter: DateFormatter
        if let cached = formatters[format] { formatter = cached }
        else {
            formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = format
            formatters[format] = formatter
        }
        if formatter.timeZone != TimeZone.current { formatter.timeZone = .current }
        return formatter.string(from: date)
    }
    static func due(_ date: Date, now: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) { return "今天 " + string(date, "HH:mm") }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) { return "明天 " + string(date, "HH:mm") }
        return string(date, calendar.component(.year, from: date) == calendar.component(.year, from: now) ? "M月d日 HH:mm" : "yyyy年M月d日 HH:mm")
    }
}
