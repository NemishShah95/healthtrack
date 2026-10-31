import SwiftData
import SwiftUI

enum Format {
    /// "7h 18m"
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int((seconds / 60).rounded())
        return total >= 60 ? "\(total / 60)h \(String(format: "%02d", total % 60))m" : "\(total)m"
    }

    static func percent(_ value: Double?) -> String {
        value.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
    }

    static func number(_ value: Double?, digits: Int = 0) -> String {
        value.map { $0.formatted(.number.precision(.fractionLength(digits))) } ?? "—"
    }
}

extension Color {
    /// Different shades for light and dark mode.
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

/// Category and status colours. Light-mode shades are deepened where the system colour
/// is too pale on white for text or icons (WCAG contrast); dark mode keeps the system colours.
enum Palette {
    static let good = Color.adaptive(light: UIColor(red: 0.118, green: 0.498, blue: 0.275, alpha: 1), dark: .systemGreen)
    static let warn = Color.adaptive(light: UIColor(red: 0.761, green: 0.369, blue: 0, alpha: 1), dark: .systemOrange)
    static let bad = Color.adaptive(light: UIColor(red: 0.78, green: 0.11, blue: 0.11, alpha: 1), dark: .systemRed)
    static let meals = warn
    static let steps = good
    static let checkIn = Color.adaptive(light: UIColor(red: 0.055, green: 0.486, blue: 0.549, alpha: 1), dark: .systemTeal)
}

extension Calendar {
    /// A timestamp on `day`: now if it's today, otherwise the same clock time on that day.
    func timestamp(on day: Date, now: Date = .now) -> Date {
        isDate(day, inSameDayAs: now) ? now : TimeOfDay(of: now, in: self).on(day, in: self)
    }
}

// MARK: - Minimal building blocks

/// A summary tile: one label, one value, an optional one-line detail and at most one quick action.
/// Tapping anywhere else opens the full page.
struct Tile<Value: View, Accessory: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    var detail: String?
    let open: () -> Void
    @ViewBuilder var value: Value
    @ViewBuilder var accessory: Accessory

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: systemImage).foregroundStyle(tint)
                        Text(title)
                    }
                    .font(.subheadline.weight(.medium))
                    value
                        .font(.title3.bold())
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 4) {
                        if let detail {
                            Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        accessory.hidden()   // reserves room for the real action drawn on top
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
                .contentShape(.rect(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens \(title.lowercased()) details")
            accessory.padding(14)
        }
    }
}

/// What a tile shows before there's anything to show. Words, not a dash: clearer, and a thin dash
/// reads as low contrast.
struct Placeholder: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).foregroundStyle(.secondary)
    }
}

/// The one quick action a tile may carry.
struct PillButton: View {
    let title: String
    let tint: Color
    var accessibilityLabel: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).foregroundStyle(.black)
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .tint(tint)
        .frame(minHeight: 44)          // full-size tap target around a small-looking pill
        .contentShape(.rect)
        .accessibilityLabel(accessibilityLabel ?? title)
    }
}

struct Ring: View {
    let value: Double?
    var size: CGFloat = 64
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(Color(.tertiarySystemFill), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: value ?? 0)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(Format.percent(value))
                .font(size > 80 ? .title.bold() : .subheadline.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(lineWidth)
        }
        .frame(width: size, height: size)
        .animation(.default, value: value)
    }
}

struct Stat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(value).font(.body.monospacedDigit().weight(.semibold)).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

extension MealTiming {
    var label: String {
        switch self {
        case .onTime: "On time"
        case .early: "Early"
        case .late: "Late"
        case .skipped: "Skipped"
        case .pending: "Not yet"
        }
    }

    var symbol: String {
        switch self {
        case .onTime: "checkmark.circle.fill"
        case .early, .late: "clock.fill"
        case .skipped: "xmark.circle"
        case .pending: "circle.dotted"
        }
    }

    var color: Color {
        switch self {
        case .onTime: Palette.good
        case .early, .late: Palette.warn
        case .skipped: Palette.bad
        case .pending: .secondary
        }
    }
}

extension SupplementStatus {
    var symbol: String {
        switch self {
        case .taken: "checkmark.circle.fill"
        case .skipped: "forward.circle"
        case .missed: "xmark.circle"
        case .pending: "circle"
        }
    }

    var color: Color {
        switch self {
        case .taken: Palette.good
        case .skipped: Palette.warn
        case .missed: Palette.bad
        case .pending: .secondary
        }
    }
}

extension Binding where Value == TimeOfDay {
    /// Lets a `DatePicker(.hourAndMinute)` edit a TimeOfDay.
    var asDate: Binding<Date> {
        Binding<Date>(
            get: { wrappedValue.on(.now, in: .current) },
            set: { wrappedValue = TimeOfDay(of: $0, in: .current) })
    }
}

// MARK: - Logging controls (work for any day)

/// One-tap amounts plus a custom entry. An accidental double-tap is ignored by the log action.
struct QuickAddButtons: View {
    let amounts: [Int]
    let unit: String
    /// Spoken unit, e.g. "millilitres".
    let noun: String
    let tint: Color
    let range: ClosedRange<Int>
    var asksForLabel = false
    let log: (Int, String) -> Bool

    @State private var showingCustom = false
    @State private var customAmount = ""
    @State private var customLabel = ""
    @State private var tapCount = 0

    var body: some View {
        HStack(spacing: 8) {
            ForEach(amounts, id: \.self) { n in
                Button(unit == "ml" ? "+\(n)" : "+\(n) \(unit)") { fire(n, "") }
                    .accessibilityLabel("Add \(n) \(noun)")
            }
            Button("Custom", systemImage: "plus") { showingCustom = true }
                .labelStyle(.iconOnly)
                .accessibilityLabel("Add a custom amount")
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .sensoryFeedback(.increase, trigger: tapCount)
        .alert("Add amount", isPresented: $showingCustom) {
            TextField(unit == "ml" ? "Millilitres" : "Grams", text: $customAmount).keyboardType(.numberPad)
            if asksForLabel { TextField("Source (optional)", text: $customLabel) }
            Button("Add") { if let n = Int(customAmount) { fire(n, customLabel) }; customAmount = ""; customLabel = "" }
            Button("Cancel", role: .cancel) { customAmount = ""; customLabel = "" }
        } message: {
            Text("Between \(range.lowerBound) and \(range.upperBound) \(unit).")
        }
    }

    private func fire(_ n: Int, _ label: String) {
        if log(n, label) { tapCount += 1 }
    }
}

/// +250 / +500 / +750 / custom, logged onto `day`.
struct WaterButtons: View {
    @Environment(\.modelContext) private var context
    let day: Date

    var body: some View {
        QuickAddButtons(amounts: Hydration.quickAddML, unit: "ml", noun: "millilitres", tint: .blue, range: Hydration.validRangeML) { ml, _ in
            context.logWater(ml, at: Calendar.current.timestamp(on: day)) != nil
        }
    }
}

/// +10 / +20 / +30 g / custom (with an optional source), logged onto `day`.
struct ProteinButtons: View {
    @Environment(\.modelContext) private var context
    let day: Date

    var body: some View {
        QuickAddButtons(amounts: Protein.quickAddGrams, unit: "g", noun: "grams of protein", tint: .pink,
                        range: Protein.validRangeGrams, asksForLabel: true) { g, label in
            context.logProtein(g, label: label, at: Calendar.current.timestamp(on: day)) != nil
        }
    }
}

/// Energy / Mood / Stress, 1–5. Three taps and done.
struct CheckInControls: View {
    @Environment(\.modelContext) private var context
    let dayKey: String
    @Query private var checkIns: [DailyCheckIn]

    init(dayKey: String) {
        self.dayKey = dayKey
        _checkIns = Query(filter: #Predicate<DailyCheckIn> { $0.day == dayKey })
    }

    var body: some View {
        let checkIn = checkIns.first
        VStack(alignment: .leading, spacing: 12) {
            row("Energy", value: checkIn?.energy) { c, v in c.energy = v }
            row("Mood", value: checkIn?.mood) { c, v in c.mood = v }
            row("Stress", value: checkIn?.stress) { c, v in c.stress = v }
        }
    }

    private func row(_ title: String, value: Int?, set: @escaping (DailyCheckIn, Int?) -> Void) -> some View {
        HStack {
            Text(title).frame(width: 64, alignment: .leading)
            Spacer(minLength: 0)
            ForEach(1...5, id: \.self) { n in
                Button {
                    let c = context.checkIn(onDay: dayKey)
                    set(c, value == n ? nil : n)   // tapping the selected value clears it
                    c.updatedAt = .now
                } label: {
                    Text("\(n)")
                        .font(.body.monospacedDigit())
                        .frame(minWidth: 36, minHeight: 36)
                        .background(value == n ? Color.accentColor : Color(.tertiarySystemFill), in: .circle)
                        .foregroundStyle(value == n ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title) \(n) of 5")
                .accessibilityAddTraits(value == n ? .isSelected : [])
            }
        }
    }
}

struct CheckInNotes: View {
    @Environment(\.modelContext) private var context
    @Query private var checkIns: [DailyCheckIn]
    @State private var text = ""
    let dayKey: String

    init(dayKey: String) {
        self.dayKey = dayKey
        _checkIns = Query(filter: #Predicate<DailyCheckIn> { $0.day == dayKey })
    }

    var body: some View {
        TextField("Notes (optional)", text: $text, axis: .vertical)
            .onAppear { text = checkIns.first?.notes ?? "" }
            .onSubmit(save)
            .onDisappear(perform: save)
    }

    private func save() {
        guard text != (checkIns.first?.notes ?? "") else { return }
        let c = context.checkIn(onDay: dayKey)
        c.notes = text
        c.updatedAt = .now
    }
}

/// One scheduled dose. Tap toggles taken; the menu offers skip. On past days "off" means missed.
struct DoseRow: View {
    @Environment(\.modelContext) private var context
    let log: SupplementLog
    var isPast = false

    var body: some View {
        let off: SupplementStatus = isPast ? .missed : .pending
        HStack {
            Button {
                context.setStatus(log.status == .taken ? off : .taken, for: log)
            } label: {
                Image(systemName: log.status.symbol)
                    .font(.title3)
                    .foregroundStyle(log.status.color)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(log.status == .taken ? "Mark \(log.supplement?.name ?? "dose") as not taken"
                                                     : "Mark \(log.supplement?.name ?? "dose") as taken")

            VStack(alignment: .leading) {
                Text(log.supplement?.name ?? "Supplement").lineLimit(2)
                Text([log.supplement?.dosageText, log.scheduledMinutes.map { TimeOfDay(0, $0).formatted() }]
                    .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Taken", systemImage: "checkmark") { context.setStatus(.taken, for: log) }
                Button("Skipped", systemImage: "forward") { context.setStatus(.skipped, for: log) }
                Button(isPast ? "Missed" : "Not yet", systemImage: "circle") { context.setStatus(off, for: log) }
            } label: {
                Text(log.status.rawValue.capitalized).font(.caption).foregroundStyle(log.status.color)
            }
        }
    }
}
