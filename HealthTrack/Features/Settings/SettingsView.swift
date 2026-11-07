import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        NavigationLink("Sleep, meals, water & activity") { GoalsView() }
                    } header: { Header("Goals") }
                    Section {
                        NavigationLink("Vitamins & supplements") { SupplementsView() }
                        NavigationLink("Reminders") { RemindersView() }
                    } header: { Header("Logging") }
                }
                .appRows()
                // A row modifier on a custom section view stretches its rows, so it styles its own rows.
                HealthAccessSection()
                Group {
                    Section("Data") {
                        NavigationLink("Data & Backup") { DataBackupView() }
                        NavigationLink("App Installation") { AppInstallationView() }
                    }
                    Section {
                        NavigationLink("Privacy") { PrivacyView() }
                    } footer: {
                        Text("HealthTrack \(Bundle.main.appVersion)")
                    }
                }
                .appRows()
            }
            .appScreen()
            .navigationTitle("Settings")
        }
    }
}

extension Bundle {
    var appVersion: String {
        "\(infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(infoDictionary?["CFBundleVersion"] as? String ?? "?"))"
    }
}

private struct HealthAccessSection: View {
    @Environment(HealthStore.self) private var health

    var body: some View {
        Section {
            switch health.access {
            case .unavailable:
                Text("Apple Health isn't available on this device.").appRows()
            case .notRequested:
                Button("Connect Apple Health") { Task { await health.requestAccess() } }.appRows()
            case .requested:
                let s = health.snapshot
                let recent = DayKey.of(Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now, calendar: .current)
                row("Sleep", !s.nights(calendar: .current).keys.filter { $0 >= recent }.isEmpty)
                row("Heart rate variability", s.hrv.keys.contains { $0 >= recent })
                row("Resting heart rate", s.restingHR.keys.contains { $0 >= recent })
                row("Steps", s.steps.keys.contains { $0 >= recent })
                row("Workouts", s.workouts.contains { $0.start >= Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now })
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text("Shows whether data arrived recently. Apple doesn't tell apps which categories you allowed, so if something's missing, open the Health app → your profile → Apps → HealthTrack and turn it on.")
        }
    }

    private func row(_ title: String, _ hasData: Bool) -> some View {
        // HStack, not Label: a Label inside LabeledContent makes the row very tall.
        LabeledContent(title) {
            HStack(spacing: 6) {
                Image(systemName: hasData ? "checkmark.circle.fill" : "minus.circle")
                Text(hasData ? "Receiving data" : "No recent data")
            }
            .foregroundStyle(hasData ? Palette.good : Palette.secondary)
            .font(.subheadline)
        }
        .appRows()
    }
}

struct GoalsView: View {
    @Environment(\.modelContext) private var context
    @State private var goals = Goals()
    @State private var loaded = false

    var body: some View {
        Form {
            Group {
                Section("Sleep") {
                    DatePicker("Bedtime", selection: $goals.bedtime.asDate, displayedComponents: .hourAndMinute)
                    DatePicker("Wake time", selection: $goals.wakeTime.asDate, displayedComponents: .hourAndMinute)
                    Picker("On time within", selection: $goals.sleepToleranceMinutes) {
                        ForEach(options([10, 15, 20, 30, 45, 60, 90], goals.sleepToleranceMinutes), id: \.self) { Text("±\($0) min").tag($0) }
                    }
                    Picker("Sleep target", selection: $goals.sleepTargetMinutes) {
                        ForEach(options(Array(stride(from: 300, through: 600, by: 15)), goals.sleepTargetMinutes), id: \.self) {
                            Text(Format.duration(Double($0 * 60))).tag($0)
                        }
                    }
                }
                Section {
                    ForEach(MealType.targeted, id: \.self) { type in
                        VStack(alignment: .leading) {
                            Text(type.rawValue.capitalized).font(.subheadline.bold())
                            HStack {
                                DatePicker("From", selection: window(type, \.start).asDate, displayedComponents: .hourAndMinute)
                                DatePicker("to", selection: window(type, \.end).asDate, displayedComponents: .hourAndMinute)
                            }
                            .labelsHidden()
                        }
                    }
                } header: {
                    Text("Meal windows")
                } footer: {
                    Text("A meal logged inside its window counts as on time.")
                }
                Section("Water") {
                    Picker("Daily target", selection: $goals.waterTargetML) {
                        ForEach(options(Array(stride(from: 1000, through: 5000, by: 250)), goals.waterTargetML), id: \.self) {
                            Text("\(String(format: "%g", Double($0) / 1000)) L").tag($0)
                        }
                    }
                }
                Section {
                    Picker("Daily target", selection: $goals.proteinTargetGrams) {
                        ForEach(options(Array(stride(from: 40, through: 250, by: 5)), goals.proteinTargetGrams), id: \.self) { Text("\($0) g").tag($0) }
                    }
                } header: {
                    Text("Protein")
                } footer: {
                    Text("Set your own target. HealthTrack doesn't recommend an intake.")
                }
                Section("Activity") {
                    Picker("Steps a day", selection: $goals.stepTarget) {
                        ForEach(options(Array(stride(from: 2000, through: 20000, by: 500)), goals.stepTarget), id: \.self) { Text($0.formatted()).tag($0) }
                    }
                    Picker("Workouts a week", selection: $goals.workoutsPerWeek) {
                        ForEach(options(Array(0...14), goals.workoutsPerWeek), id: \.self) { Text("\($0)").tag($0) }
                    }
                }
            }
            .appRows()
        }
        .appScreen()
        .navigationTitle("Goals")
        .onAppear {
            goals = context.settings().goals
            loaded = true
        }
        .onChange(of: goals) { _, new in if loaded { context.settings().goals = new } }
        .onDisappear { Task { await Reminders.reschedule(context) } }
    }

    /// Dropdown values, plus the stored one if it isn't in the list (set by an older version).
    private func options(_ base: [Int], _ current: Int) -> [Int] {
        base.contains(current) ? base : (base + [current]).sorted()
    }

    private func window(_ type: MealType, _ edge: WritableKeyPath<MealWindow, TimeOfDay>) -> Binding<TimeOfDay> {
        Binding {
            goals.mealWindows[type, default: MealWindow.defaults[type]!][keyPath: edge]
        } set: { newValue in
            var w = goals.mealWindows[type, default: MealWindow.defaults[type]!]
            w[keyPath: edge] = newValue
            if w.end < w.start { w.end = w.start }   // windows can't cross midnight
            goals.mealWindows[type] = w
        }
    }
}

struct RemindersView: View {
    @Environment(\.modelContext) private var context
    @State private var r = ReminderSettings()
    @State private var loaded = false

    var body: some View {
        Form {
            Group {
                Section {
                    Toggle("Meals (at the start of each window)", isOn: $r.meals)
                    Toggle("Water (3 times a day)", isOn: $r.water)
                    if r.water {
                        ForEach(r.waterTimes.indices, id: \.self) { i in
                            DatePicker("Reminder \(i + 1)", selection: $r.waterTimes[i].asDate, displayedComponents: .hourAndMinute)
                        }
                    }
                    Toggle("Bedtime (30 min before)", isOn: $r.bedtime)
                    Toggle("Daily check-in", isOn: $r.checkIn)
                    if r.checkIn { DatePicker("At", selection: $r.checkInTime.asDate, displayedComponents: .hourAndMinute) }
                    Toggle("Weekly backup (Sundays)", isOn: $r.backup)
                } footer: {
                    Text("Vitamin reminders are set on each vitamin. The app-refresh reminder is in App Installation.")
                }
            }
            .appRows()
        }
        .appScreen()
        .navigationTitle("Reminders")
        .onAppear {
            r = context.settings().reminders
            loaded = true
        }
        .onChange(of: r) { _, new in if loaded { context.settings().reminders = new } }
        .onDisappear { Task { await Reminders.reschedule(context) } }
    }
}

struct DataBackupView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [AppSettings]
    @State private var share: SharedFile?
    @State private var importing = false
    @State private var pendingImport: ExportBundle?
    @State private var message: String?

    struct SharedFile: Identifiable {
        let url: URL
        var id: URL { url }
    }

    var body: some View {
        Form {
            Group {
                Section {
                    Button("Export all data", systemImage: "square.and.arrow.up") { export(.all) }
                    Button("Export JSON", systemImage: "doc") { export(.json) }
                    Button("Export CSV", systemImage: "tablecells") { export(.csv) }
                    LabeledContent("Last export",
                                   value: settingsRows.first?.lastExportDate?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                } header: {
                    Text("Export")
                } footer: {
                    Text("JSON is a complete backup you can restore. CSV opens in Numbers or Excel. Apple Health data isn't included; it stays in Apple Health. Exports contain personal health information, so keep them somewhere private.")
                }
                Section {
                    Toggle("Weekly backup reminder", isOn: Binding(
                        get: { settingsRows.first?.reminders.backup ?? false },
                        set: { context.settings().reminders.backup = $0; Task { await Reminders.reschedule(context) } }))
                }
                Section {
                    Button("Restore from JSON backup…", systemImage: "square.and.arrow.down") { importing = true }
                } footer: {
                    Text("Adds anything in the backup that isn't already here. Nothing is deleted or duplicated. Goals are replaced with the backup's.")
                }
            }
            .appRows()
        }
        .appScreen()
        .navigationTitle("Data & Backup")
        .sheet(item: $share) { file in
            ActivityView(items: [file.url]) { completed in
                if completed { context.settings().lastExportDate = .now }
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                pendingImport = try ExportBundle.decode(Data(contentsOf: url))
            } catch ExportBundle.ImportError.newerFormat {
                message = "This backup was made by a newer version of HealthTrack. Update the app first."
            } catch {
                message = "That file isn't a HealthTrack backup."
            }
        }
        .confirmationDialog("Restore this backup?", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
                            titleVisibility: .visible, presenting: pendingImport) { bundle in
            Button("Restore") {
                do {
                    let added = try context.importBundle(bundle)
                    context.syncSupplementLogs()
                    message = "Restored \(added) record\(added == 1 ? "" : "s")."
                } catch {
                    message = "Restore failed: \(error.localizedDescription). Nothing was changed."
                }
            }
        } message: { bundle in
            Text("Backup from \(bundle.exportedAt.formatted(date: .abbreviated, time: .shortened)): \(bundle.meals.count) meals, \(bundle.water.count) water entries, \(bundle.supplements.count) supplements, \(bundle.checkIns.count) check-ins.")
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {}
    }

    private func export(_ kind: ExportFiles.Kind) {
        do {
            try context.save()
            share = SharedFile(url: try ExportFiles.make(kind, bundle: context.exportBundle(appVersion: Bundle.main.appVersion)))
        } catch {
            message = "Export failed: \(error.localizedDescription)"
        }
    }
}

/// Share sheet that reports whether the user actually saved/sent the file.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    var completion: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in completion(completed) }
        return vc
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct PrivacyView: View {
    var body: some View {
        Form {
            Group {
                Section {
                    Label("Everything stays on this iPhone.", systemImage: "iphone")
                    Label("No account, no cloud database, no internet connection needed.", systemImage: "wifi.slash")
                    Label("No analytics, tracking or advertising.", systemImage: "eye.slash")
                    Label("No AI services. Insights are simple calculations done on the phone.", systemImage: "function")
                    Label("Apple Health is read-only. HealthTrack never writes to it.", systemImage: "heart")
                } footer: {
                    Text("Data only leaves the phone when you export it yourself. HealthTrack gives observations about habits, never medical advice or diagnosis.")
                }
            }
            .appRows()
        }
        .appScreen()
        .navigationTitle("Privacy")
    }
}
