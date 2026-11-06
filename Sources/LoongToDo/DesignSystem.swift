import SwiftUI

enum Style {
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.66, green: 0.72, blue: 0.98, alpha: 1)
            : NSColor(red: 0.29, green: 0.36, blue: 0.73, alpha: 1)
    })
    static let accentFill = Color(red: 0.29, green: 0.36, blue: 0.73)
    static let accentSoft = Color(red: 0.57, green: 0.64, blue: 0.90)
    static let orange = Color(red: 0.79, green: 0.44, blue: 0.24)
    static let ink = Color.primary
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
    @Environment(\.colorScheme) var scheme
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                (scheme == .dark ? Color(red: 0.09, green: 0.10, blue: 0.15) : Color(red: 0.95, green: 0.96, blue: 0.98))
                // Soft falloffs without large offscreen Gaussian-blur passes.
                RadialGradient(colors: [Style.accentSoft.opacity(0.30), .clear], center: .topTrailing, startRadius: 0, endRadius: proxy.size.width * 0.9)
                RadialGradient(colors: [Color(red: 0.75, green: 0.69, blue: 0.91).opacity(0.22), .clear], center: .bottomLeading, startRadius: 0, endRadius: proxy.size.width * 0.65)
                RadialGradient(colors: [.white.opacity(scheme == .dark ? 0.025 : 0.50), .clear], center: .bottom, startRadius: 0, endRadius: proxy.size.height * 0.75)
            }
        }.ignoresSafeArea().allowsHitTesting(false)
    }
}

struct GlassSurface: ViewModifier {
    var radius: CGFloat = 22
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: radius).fill(Color(nsColor: .windowBackgroundColor))
                } else {
                    // Cards use a translucent tint, avoiding a live backdrop filter per row.
                    // Shadow only the stable surface shape, never its text or controls.
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(colors: scheme == .dark
                            ? [Color(red: 0.17, green: 0.19, blue: 0.27).opacity(0.95), Color(red: 0.13, green: 0.15, blue: 0.22).opacity(0.9)]
                            : [.white.opacity(0.72), .white.opacity(0.36)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: .black.opacity(scheme == .dark ? 0.15 : 0.045), radius: 9, x: 0, y: 5)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.22 : 0.95), .white.opacity(0.12), .white.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            }
    }
}

extension View {
    func glassPanel(radius: CGFloat = 22) -> some View { modifier(GlassSurface(radius: radius)) }
    func floatingCard(radius: CGFloat = 22) -> some View { modifier(FloatingCard(radius: radius)) }
    @ViewBuilder func liquidControl() -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            self.glassPanel(radius: 30)
        }
        #else
        self.glassPanel(radius: 30)
        #endif
    }
}

struct SoftButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .padding(.horizontal, 18).padding(.vertical, 12)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background {
                Capsule().fill(LinearGradient(colors: prominent
                    ? [Style.accentFill.opacity(0.88), Style.accentFill]
                    : [Color.white.opacity(scheme == .dark ? 0.12 : 0.85), Color.white.opacity(scheme == .dark ? 0.05 : 0.3)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: (prominent ? Style.accent : .black).opacity(enabled ? (prominent ? 0.18 : 0.05) : 0), radius: 6, x: 0, y: 4)
            }
            .overlay(Capsule().strokeBorder(.white.opacity(prominent ? 0.3 : 0.5)))
            .opacity(enabled ? 1 : 0.4)
            .modifier(SpringInteraction(isPressed: configuration.isPressed, pressedScale: 0.92, hoverScale: 1.035))
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
