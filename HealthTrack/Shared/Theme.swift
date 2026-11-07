import SwiftUI

// HealthTrack's look: dark navy-to-teal background with soft glows, translucent dark cards,
// light-weight numbers with small units, lime for progress and actions, teal for sleep.
// Design by Nemish Shah. Every value is documented in README.md → Design.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

/// The app is dark-only, so every colour is a single value. Text keeps at least 6.8:1 even on the glows
/// (secondary on the brightest glow; 9:1 on `card`).
enum Palette {
    // Background
    static let backgroundTop = Color(hex: 0x0B1E2B)
    static let backgroundBottom = Color(hex: 0x050C11)
    static let glowTeal = Color(hex: 0x1D5E5C)
    static let glowLime = Color(hex: 0x3F6220)
    // Surfaces
    // Opaque on purpose: the accessibility audit can't measure contrast through translucent surfaces.
    static let card = Color(hex: 0x0E1C23)
    static let row = Color(hex: 0x10222A)
    static let stroke = Color.white.opacity(0.07)
    static let track = Color.white.opacity(0.10)
    // Text
    static let text = Color(hex: 0xF1F5F4)
    static let secondary = Color(hex: 0xAEC0C4)
    // Accents
    static let lime = Color(hex: 0xC8F25C)
    static let limeDeep = Color(hex: 0x86D65A)
    static let teal = Color(hex: 0x4FC9BD)
    // Sleep stages (chart only)
    static let awake = Color(hex: 0xE6F6F3)
    static let rem = Color(hex: 0x86E6DA)
    static let core = Color(hex: 0x3DB3A9)
    static let deep = Color(hex: 0x1F7C78)
    // Status and categories
    static let good = lime
    static let warn = Color(hex: 0xFFC266)
    static let bad = Color(hex: 0xFF7A7A)
    static let water = Color(hex: 0x62D2F5)
    static let protein = Color(hex: 0xFF9DB5)
    static let vitamins = Color(hex: 0xBCA8FF)
    static let meals = warn
    static let steps = lime
    static let gym = lime
    static let checkIn = teal
}

/// Navy-to-black with a teal glow behind the top cards and a faint lime glow lower down.
struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.backgroundTop, Palette.backgroundBottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Palette.glowTeal.opacity(0.40), .clear], center: UnitPoint(x: 0.8, y: 0.12),
                           startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Palette.glowLime.opacity(0.24), .clear], center: UnitPoint(x: 0.15, y: 0.62),
                           startRadius: 0, endRadius: 380)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Full-screen gradient behind a List, Form or ScrollView. Text defaults to opaque colours: section headers
    /// use the secondary level, and Apple's own see-through grey fails the contrast audit on a custom background.
    func appScreen() -> some View {
        scrollContentBackground(.hidden)
            .foregroundStyle(Palette.text, Palette.secondary)
            .background(AppBackground())
    }

    /// The dark translucent card every summary sits on.
    func card(cornerRadius: CGFloat = 26) -> some View {
        background(Palette.card, in: .rect(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Palette.stroke))
            .contentShape(.rect(cornerRadius: cornerRadius))
    }

    /// List rows in the card colour (apply to a Section or a Group of sections).
    func appRows() -> some View { listRowBackground(Palette.row) }
}

/// "7h 16m", "8,412 steps": light numbers, small units, as in the design.
struct ValueText: View {
    let parts: [(text: String, isUnit: Bool)]
    @ScaledMetric private var size: CGFloat

    init(_ parts: [(text: String, isUnit: Bool)], size: CGFloat = 34) {
        self.parts = parts
        _size = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle)
    }

    init(_ number: String, unit: String? = nil, size: CGFloat = 34) {
        self.init([(number, false)] + (unit.map { [(" " + $0, true)] } ?? []), size: size)
    }

    var body: some View {
        parts.reduce(Text("")) { text, part in
            text + Text(part.text).font(part.isUnit ? .system(size: size * 0.45, weight: .regular)
                                                    : .system(size: size, weight: .light))
        }
        .monospacedDigit()
        .foregroundStyle(Palette.text)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    /// 26160 s → "7" "h " "16" "m"
    static func duration(_ seconds: TimeInterval, size: CGFloat = 34) -> ValueText {
        let total = Int((seconds / 60).rounded())
        let parts: [(String, Bool)] = total >= 60 ? [("\(total / 60)", false), ("h ", true), (String(format: "%02d", total % 60), false), ("m", true)]
                                                  : [("\(total)", false), ("m", true)]
        return ValueText(parts.map { (text: $0.0, isUnit: $0.1) }, size: size)
    }
}

/// Thin capsule progress bar.
struct ProgressBar: View {
    let value: Double
    var tint: Color = Palette.lime

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.track)
                Capsule().fill(tint).frame(width: max(6, geo.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
        .animation(.default, value: value)
    }
}

/// A list section header drawn by the app, so its colour is explicit (the audit misreads the system's).
struct Header: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.text).textCase(nil)
    }
}

/// Section title used on the dashboards.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.headline.weight(.regular)).foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}
