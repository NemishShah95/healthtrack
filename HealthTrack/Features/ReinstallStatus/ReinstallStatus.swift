import SwiftData
import SwiftUI

/// Detects Xcode reinstalls and computes when the next free-provisioning refresh is due.
@MainActor
enum ReinstallTracker {
    /// Call on every launch / foreground.
    static func recordLaunch(_ settings: AppSettings, now: Date = .now) {
        let binaryDate = Bundle.main.executableURL
            .flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
        let fingerprint = "\(binaryDate?.timeIntervalSince1970 ?? 0)|\(profileExpiration?.timeIntervalSince1970 ?? 0)"
        if settings.installationDate == nil { settings.installationDate = now }
        if settings.installFingerprint != fingerprint {
            settings.installFingerprint = fingerprint
            settings.lastProvisioningRefreshDate = now
        }
    }

    /// Expiry of the free signing profile. Only present on a physical device.
    static let profileExpiration: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8)),
              let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any]
        else { return nil }
        return plist["ExpirationDate"] as? Date
    }()

    static func lastRefresh(_ settings: AppSettings, now: Date = .now) -> Date? {
        // QA: `-refreshDaysAgo 5` pretends the last refresh was 5 days ago.
        if let days = UserDefaults.standard.object(forKey: "refreshDaysAgo") as? Int {
            return Calendar.current.date(byAdding: .day, value: -days, to: now)
        }
        #if targetEnvironment(simulator)
        return nil   // simulator builds never expire
        #else
        return settings.lastProvisioningRefreshDate
        #endif
    }

    static func nextRefresh(_ settings: AppSettings, now: Date = .now) -> Date? {
        lastRefresh(settings, now: now).map {
            ReinstallSchedule.nextSuggestedRefresh(lastRefresh: $0, profileExpiration: profileExpiration, calendar: .current)
        }
    }

    static func status(_ settings: AppSettings, now: Date = .now) -> RefreshStatus {
        guard let next = nextRefresh(settings, now: now) else { return .ok }
        return ReinstallSchedule.status(now: now, nextSuggested: next, calendar: .current)
    }
}

/// Today-screen banner shown when a refresh is due soon or today.
struct RefreshBanner: View {
    let status: RefreshStatus

    var body: some View {
        switch status {
        case .ok:
            EmptyView()
        case .dueSoon(let date):
            banner("App refresh due soon",
                   "Reconnect to your personal Mac and run HealthTrack from Xcode before \(date.formatted(.dateTime.weekday(.wide).day().month())).",
                   tint: .orange)
        case .dueToday:
            banner("App refresh recommended today",
                   "Connect your iPhone to your personal Mac and press Run in Xcode.",
                   tint: .red)
        }
    }

    private func banner(_ title: String, _ message: String, tint: Color) -> some View {
        NavigationLink {
            AppInstallationView()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: "arrow.triangle.2.circlepath").font(.headline).foregroundStyle(tint)
                Text(message).font(.subheadline)
                Text("Your data stays intact when you refresh through Xcode without deleting the app. For extra safety, export a backup first.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(tint.opacity(0.12), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

/// Settings → App Installation.
struct AppInstallationView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [AppSettings]

    var body: some View {
        let settings = settingsRows.first
        Form {
            Section("Status") {
                LabeledContent("Installed", value: settings?.installationDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                LabeledContent("Last refresh", value: settings?.lastProvisioningRefreshDate?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                LabeledContent("Suggested next refresh",
                               value: settings.flatMap { ReinstallTracker.nextRefresh($0) }?.formatted(date: .abbreviated, time: .omitted) ?? "Not needed in the simulator")
                if let expiry = ReinstallTracker.profileExpiration {
                    LabeledContent("Signing expires", value: expiry.formatted(date: .abbreviated, time: .shortened))
                }
                if let settings {
                    Toggle("Remind me the day it's due", isOn: Binding(
                        get: { settings.refreshReminderEnabled },
                        set: { settings.refreshReminderEnabled = $0 }))
                }
            }
            Section {
                NavigationLink("Export data first") { DataBackupView() }
            } header: {
                Text("Backup before reinstall")
            } footer: {
                Text("Refreshing through Xcode keeps your data. A backup protects you if something goes wrong.")
            }
            Section("How to refresh HealthTrack") {
                ForEach(Array(Self.steps.enumerated()), id: \.offset) { i, step in
                    Label { Text(step) } icon: { Text("\(i + 1).").monospacedDigit() }
                }
            }
        }
        .navigationTitle("App Installation")
    }

    static let steps = [
        "Connect iPhone to personal Mac.",
        "Open HealthTrack.xcodeproj in Xcode.",
        "Select your iPhone.",
        "Make sure your Personal Team is selected.",
        "Press Run.",
        "Do NOT delete the existing HealthTrack app first.",
        "Confirm the app opens and your data is there.",
    ]
}
