import SwiftData
import SwiftUI

/// First launch: explain why HealthTrack reads Apple Health, then ask once.
struct OnboardingView: View {
    @Environment(HealthStore.self) private var health
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Palette.lime)
                    .accessibilityHidden(true)
                Text("Welcome to HealthTrack").font(.system(.largeTitle, weight: .light)).foregroundStyle(Palette.text)
                Label("Reads your sleep, HRV, resting heart rate, steps and workouts from Apple Health. Your Amazfit data arrives there through Zepp.",
                      systemImage: "heart")
                Label("You log meals, water, supplements and a quick check-in here. It takes under 30 seconds a day.",
                      systemImage: "square.and.pencil")
                Label("Everything stays on this iPhone. No account, no internet, no tracking.", systemImage: "lock")
                Text("On the next screen Apple asks which categories to share. Turn them all on for the full picture. You can change this later in the Health app → your profile → Apps → HealthTrack.")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondary)
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button {
                    Task {
                        await health.requestAccess()
                        finish()
                    }
                } label: {
                    Text("Connect Apple Health").font(.headline).foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Palette.lime, in: .capsule)
                }
                .buttonStyle(.plain)
                Button("Not now", action: finish).foregroundStyle(Palette.lime).frame(minHeight: 44)
            }
            .padding()
        }
        .foregroundStyle(Palette.text)
        .background(AppBackground())
        .interactiveDismissDisabled()
    }

    private func finish() {
        context.settings().hasCompletedOnboarding = true
        dismiss()
    }
}
