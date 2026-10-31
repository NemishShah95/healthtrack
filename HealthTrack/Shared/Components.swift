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
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tint)
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
                accessory
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
        .contentShape(.rect(cornerRadius: 20))
        .onTapGesture(perform: open)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Open \(title)", open)
    }
}

/// The one quick action a tile may carry.
struct PillButton: View {
    let title: String
    let tint: Color
    var accessibilityLabel: String?
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.caption.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .tint(tint)
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
        case .onTime: .green
        case .early, .late: .orange
        case .skipped: .red
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
        case .taken: .green
        case .skipped: .orange
        case .missed: .red
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

/// +250 / +500 / +750 / custom for `day`. One tap logs; an accidental double-tap is ignored.
struct WaterButtons: View {
    @Environment(\.modelContext) private var context
    let day: Date
    @State private var showingCustom = false
    @State private var customML = ""
    @State private var tapCount = 0

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Hydration.quickAddML, id: \.self) { ml in
                Button("+\(ml)") { log(ml) }
                    .accessibilityLabel("Add \(ml) millilitres")
            }
            Button("Custom", systemImage: "plus") { showingCustom = true }
                .labelStyle(.iconOnly)
                .accessibilityLabel("Add a custom amount")
        }
        .buttonStyle(.bordered)
        .tint(.blue)
        .sensoryFeedback(.increase, trigger: tapCount)
        .alert("Add water", isPresented: $showingCustom) {
            TextField("Millilitres", text: $customML).keyboardType(.numberPad)
            Button("Add") { if let ml = Int(customML) { log(ml) }; customML = "" }
            Button("Cancel", role: .cancel) { customML = "" }
        } message: {
            Text("Between 1 and 5000 ml.")
        }
    }

    private func log(_ ml: Int) {
        if context.logWater(ml, at: Calendar.current.timestamp(on: day)) != nil { tapCount += 1 }
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
