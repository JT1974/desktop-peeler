import SwiftUI
import AppKit

/// Visual identity, taken from the presoft brand guideline (dark and light palettes; by
/// default the app follows the macOS appearance, changeable in Settings and the top bar):
/// night-sky surfaces, hairline borders instead of shadows, one electric cyan accent
/// used sparingly, Sora for headings, Inter for text, JetBrains Mono for labels and data.
enum Brand {
    // Colours. Each one has a dark value (the brand default) and a light value from
    // the same guideline, and follows the theme chosen with the switcher in the top bar.
    private static func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> NSColor {
        return NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
    }

    private static func themed(dark: NSColor, light: NSColor) -> Color {
        let dynamic = NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? dark : light
        })
        return Color(nsColor: dynamic)
    }

    static let bg = themed(dark: rgb(5, 7, 13), light: rgb(255, 255, 255))               // #05070d / #ffffff
    static let bg2 = themed(dark: rgb(8, 11, 20), light: rgb(238, 242, 248))             // #080b14 / #eef2f8
    static let surface = themed(dark: rgb(11, 16, 32), light: rgb(255, 255, 255))        // #0b1020 / #ffffff
    static let surface2 = themed(dark: rgb(17, 24, 48), light: rgb(238, 242, 248))       // #111830 / #eef2f8
    static let selected = themed(dark: rgb(17, 24, 48), light: rgb(255, 255, 255))       // selected sidebar item
    static let text = themed(dark: rgb(232, 241, 255), light: rgb(5, 7, 13))             // #e8f1ff / #05070d
    static let text2 = themed(dark: rgb(169, 183, 208), light: rgb(51, 64, 90))          // #a9b7d0 / #33405a
    static let muted = themed(dark: rgb(111, 125, 153), light: rgb(91, 104, 128))        // #6f7d99 / #5b6880
    static let accent = themed(dark: rgb(62, 224, 255), light: rgb(62, 224, 255))        // #3ee0ff in both
    static let accentText = themed(dark: rgb(62, 224, 255), light: rgb(0, 112, 140))     // #3ee0ff / #00708c
    static let onAccent = themed(dark: rgb(2, 16, 24), light: rgb(2, 16, 24))            // #021018 in both
    static let line = themed(dark: rgb(160, 200, 255, 0.09), light: rgb(5, 7, 13, 0.08))
    static let line2 = themed(dark: rgb(160, 200, 255, 0.16), light: rgb(5, 7, 13, 0.14))
    static let line3 = themed(dark: rgb(160, 200, 255, 0.34), light: rgb(5, 7, 13, 0.30))

    // Shapes
    static let radiusSmall: CGFloat = 10

    // Fonts. The font files are bundled in Resources/Fonts; if one is missing,
    // SwiftUI falls back to the system font.
    static func display(_ size: CGFloat) -> Font {
        return Font.custom("Sora-SemiBold", size: size)
    }

    static func body(_ size: CGFloat) -> Font {
        return Font.custom("Inter-Regular", size: size)
    }

    static func strong(_ size: CGFloat) -> Font {
        return Font.custom("Inter-SemiBold", size: size)
    }

    static func mono(_ size: CGFloat) -> Font {
        return Font.custom("JetBrainsMono-Regular", size: size)
    }
}

// MARK: - Buttons

/// The one cyan call-to-action of a screen.
struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        AccentButtonBody(configuration: configuration)
    }
}

private struct AccentButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(Brand.strong(13))
            .foregroundColor(Brand.onAccent)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Capsule().fill(Brand.accent))
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1.0) : 0.3)
            .contentShape(Capsule())
    }
}

/// Secondary actions: outlined pill.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GhostButtonBody(configuration: configuration)
    }
}

private struct GhostButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(Brand.strong(13))
            .foregroundColor(Brand.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Capsule().fill(configuration.isPressed ? Brand.surface2 : Brand.surface))
            .overlay(Capsule().stroke(Brand.line3, lineWidth: 1))
            .opacity(isEnabled ? 1.0 : 0.4)
            .contentShape(Capsule())
    }
}

// MARK: - Checkbox

struct BrandCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        BrandCheckboxBody(configuration: configuration)
    }
}

private struct BrandCheckboxBody: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Brand.bg)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(configuration.isOn ? Brand.accentText : Brand.line3, lineWidth: 1.5)
                    if configuration.isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Brand.accentText)
                    }
                }
                .frame(width: 17, height: 17)
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1.0 : 0.35)
    }
}

// MARK: - Building blocks

/// Small upper-case label in mono type with the brand's cyan dash in front.
struct Eyebrow: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Brand.accent)
                .frame(width: 10, height: 2)
            Text(text.uppercased())
                .font(Brand.mono(10))
                .foregroundColor(Brand.muted)
        }
    }
}

/// Outlined pill used for status labels. Meaning is carried by the words, not by colour.
struct Pill: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(Brand.mono(9))
            .foregroundColor(Brand.text2)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .overlay(Capsule().stroke(Brand.line3, lineWidth: 1))
    }
}

/// Page header: eyebrow, Sora title, lead text.
struct PaneHeader: View {
    let eyebrow: String
    let title: String
    let lead: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: eyebrow)
            Text(title)
                .font(Brand.display(26))
                .foregroundColor(Brand.text)
            Text(lead)
                .font(Brand.body(13))
                .foregroundColor(Brand.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct CardModifier: ViewModifier {
    var radius: CGFloat = Brand.radiusSmall

    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Brand.surface))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Brand.line2, lineWidth: 1))
    }
}

extension View {
    /// Brand card: surface fill, hairline border, no shadow.
    func brandCard() -> some View {
        return modifier(CardModifier())
    }
}

// MARK: - Theme switcher

/// Applies the chosen theme ("system", "dark" or "light") to every window of the app.
enum Appearance {
    static func apply(_ theme: String) {
        switch theme {
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        default: NSApp.appearance = nil      // follow macOS
        }
    }
}

/// Three-way theme switch (same as macOS, dark, light), shown in the top bar.
struct ThemeSwitch: View {
    @Binding var theme: String

    var body: some View {
        HStack(spacing: 2) {
            option(value: "system", symbol: "circle.lefthalf.filled", help: L("Same as macOS"))
            option(value: "dark", symbol: "moon.fill", help: L("Dark theme"))
            option(value: "light", symbol: "sun.max.fill", help: L("Light theme"))
        }
        .padding(3)
        .background(Capsule().fill(Brand.bg))
        .overlay(Capsule().stroke(Brand.line3, lineWidth: 1))
    }

    private func option(value: String, symbol: String, help: String) -> some View {
        let isOn = theme == value
        return Button(action: { theme = value }) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isOn ? Brand.text : Brand.muted)
                .frame(width: 30, height: 20)
                .background(Capsule().fill(isOn ? Brand.surface2 : Color.clear))
                .overlay(Capsule().stroke(isOn ? Brand.line2 : Color.clear, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
