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

extension Calendar {
    /// A timestamp on `day`: now if it's today, otherwise the same clock time on that day.
    func timestamp(on day: Date, now: Date = .now) -> Date {
        isDate(day, inSameDayAs: now) ? now : TimeOfDay(of: now, in: self).on(day, in: self)
    }
}

// MARK: - Minimal building blocks

/// A summary tile: one label, one value, an optional one-line detail and at most one quick action.
/// Tapping anywhere else opens the full page. The tile is one button whose label starts with `title`.
struct Tile<Value: View, Accessory: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    var detail: String?
    var minHeight: CGFloat = 132
    let open: () -> Void
    @ViewBuilder var value: Value
    @ViewBuilder var accessory: Accessory

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(title).font(.subheadline).foregroundStyle(Palette.secondary)
                        Spacer(minLength: 4)
                        Image(systemName: systemImage).font(.subheadline).foregroundStyle(tint)
                    }
                    value
                        .font(.system(.title, weight: .light))
                        .foregroundStyle(Palette.text)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 4) {
                        if let detail {
                            Text(detail).font(.caption).foregroundStyle(Palette.secondary).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        accessory.hidden()   // reserves room for the real action drawn on top
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
                .card()
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens \(title.lowercased()) details")
            accessory.padding(12)
        }
    }
}

/// What a tile shows before there's anything to show. Words, not a dash.
struct Placeholder: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).foregroundStyle(Palette.secondary)
    }
}

/// The one quick action a tile may carry: a lime capsule with dark text.
struct PillButton: View {
    let title: String
    var tint: Color = Palette.lime
    var accessibilityLabel: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(tint, in: .capsule)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)          // full-size tap target around a small-looking pill
        .contentShape(.rect)
        .accessibilityLabel(accessibilityLabel ?? title)
    }
}

/// Progress ring with a lime gradient arc and a light percentage in the middle.
struct Ring: View {
    let value: Double?
    var size: CGFloat = 64
    var lineWidth: CGFloat = 8
    var label: String?

    var body: some View {
        ZStack {
            Circle().stroke(Palette.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, value ?? 0))
                .stroke(AngularGradient(colors: [Palette.limeDeep, Palette.lime, Palette.lime], center: .center,
                                        startAngle: .degrees(0), endAngle: .degrees(360 * max(0.01, value ?? 0))),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(value == nil ? 0 : 1)
            VStack(spacing: 0) {
                Text(label ?? Format.percent(value))
                    .font(.system(size: size * 0.24, weight: .light))
                    .foregroundStyle(Palette.text)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }
            .padding(lineWidth * 1.5)
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
            Text(label).font(.caption).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
            Text(value).font(.system(.title3, weight: .light).monospacedDigit()).foregroundStyle(Palette.text)
                .fixedSize(horizontal: false, vertical: true)
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

/// One-tap amount buttons. An accidental double-tap is ignored by the log action.
private struct AmountButton: View {
    let title: String
    let label: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .tint(tint)
            .accessibilityLabel(label)
    }
}

/// +250 / +500 / +750, plus a dropdown of other amounts, logged onto `day`.
struct WaterButtons: View {
    @Environment(\.modelContext) private var context
    let day: Date
    @State private var logged = 0

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Hydration.quickAddML, id: \.self) { ml in
                AmountButton(title: "+\(ml)", label: "Add \(ml) millilitres", tint: Palette.water) { log(ml) }
            }
            Menu {
                ForEach(Hydration.otherAmountsML, id: \.self) { ml in
                    Button("\(ml) ml") { log(ml) }
                }
            } label: {
                Image(systemName: "chevron.down.circle").font(.title3).foregroundStyle(Palette.water)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Other amount")
        }
        .sensoryFeedback(.increase, trigger: logged)
    }

    private func log(_ ml: Int) {
        if context.logWater(ml, at: Calendar.current.timestamp(on: day)) != nil { logged += 1 }
    }
}

/// +10 / +20 / +30 g, plus "Other…" for any amount with an optional source, logged onto `day`.
struct ProteinButtons: View {
    @Environment(\.modelContext) private var context
    let day: Date
    @State private var logged = 0
    @State private var adding = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Protein.quickAddGrams, id: \.self) { g in
                AmountButton(title: "+\(g) g", label: "Add \(g) grams of protein", tint: Palette.protein) {
                    if context.logProtein(g, at: Calendar.current.timestamp(on: day)) != nil { logged += 1 }
                }
            }
            Button { adding = true } label: {
                Image(systemName: "chevron.down.circle").font(.title3).foregroundStyle(Palette.protein)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Other amount")
        }
        .sensoryFeedback(.increase, trigger: logged)
        .sheet(isPresented: $adding) { ProteinAddSheet(day: day).presentationDetents([.medium]) }
    }
}

/// Any amount of protein and where it came from, both picked from dropdowns.
struct ProteinAddSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let day: Date
    @State private var grams = 25
    @State private var source = ""
    @State private var recent: [String] = []

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Picker("Amount", selection: $grams) {
                        ForEach(Protein.pickerGrams, id: \.self) { Text("\($0) g").tag($0) }
                    }
                    Picker("Source", selection: $source) {
                        Text("Not specified").tag("")
                        ForEach(sources, id: \.self) { Text($0).tag($0) }
                    }
                }
                .appRows()
            }
            .appScreen()
            .navigationTitle("Add protein")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        context.logProtein(grams, label: source, at: Calendar.current.timestamp(on: day))
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear { recent = context.recentProteinSources() }
        }
    }

    private var sources: [String] {
        var seen = Set<String>()
        return (recent + Protein.commonSources).filter { seen.insert($0.lowercased()).inserted }
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
            Text(title).foregroundStyle(Palette.text).frame(width: 64, alignment: .leading)
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
                        .background(value == n ? Palette.lime : Palette.track, in: .circle)
                        .foregroundStyle(value == n ? Color.black : Palette.text)
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
                    .font(.caption).foregroundStyle(Palette.secondary)
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
