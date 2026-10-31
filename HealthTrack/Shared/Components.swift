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

/// Rounded container used by the Today screen.
struct Card<Content: View>: View {
    let title: String
    let systemImage: String
    var tint: Color = .accentColor
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }
}

/// A labelled value, e.g. "Deep  1h 12m".
struct Stat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.body.monospacedDigit().weight(.semibold))
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
        case .early, .late: "clock.badge.exclamationmark"
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

// MARK: - Shared logging controls

/// +250 / +500 / +750 / custom. One tap logs; an accidental double-tap is ignored.
struct WaterButtons: View {
    @Environment(\.modelContext) private var context
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
        if context.logWater(ml) != nil { tapCount += 1 }
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
        VStack(alignment: .leading, spacing: 10) {
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

/// One scheduled dose. Tap toggles taken; the menu offers skip.
struct DoseRow: View {
    @Environment(\.modelContext) private var context
    let log: SupplementLog

    var body: some View {
        HStack {
            Button {
                context.setStatus(log.status == .taken ? .pending : .taken, for: log)
            } label: {
                Image(systemName: log.status.symbol)
                    .font(.title3)
                    .foregroundStyle(log.status.color)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(log.status == .taken ? "Mark as not taken" : "Mark as taken")

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
                Button("Not yet", systemImage: "circle") { context.setStatus(.pending, for: log) }
            } label: {
                Text(log.status.rawValue.capitalized).font(.caption).foregroundStyle(log.status.color)
            }
        }
    }
}
