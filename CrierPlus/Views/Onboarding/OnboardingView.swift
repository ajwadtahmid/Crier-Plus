import SwiftUI
import UIKit

struct OnboardingView: View {
    @AppStorage(AppStorageKeys.userName) private var storedUserName: String = ""
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding: Bool = false
    @State private var name: String = ""
    @State private var isContinuing = false
    @State private var isShowingNotificationDeniedAlert = false
    @FocusState private var isNameFieldFocused: Bool

    private let audioService = AudioGenerationService()
    private let notificationService = NotificationService()
    private let alarmService = AlarmKitService()

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                Text("Welcome to Crier+")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Color.appTextPrimary)
                Text("What should I call you?")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Color.appTextSecondary)
            }

            TextField("Your name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
                .submitLabel(.continue)
                .onSubmit(continueOnboarding)
                .disabled(isContinuing)
                .padding(.horizontal, Theme.Spacing.xl)
                .accessibilityLabel("Your name")

            Button(action: continueOnboarding) {
                if isContinuing {
                    ProgressView()
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.appPrimary)
            .disabled(trimmedName.isEmpty || isContinuing)
            .frame(minHeight: Theme.Layout.minimumTapTarget)
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .background(Color.appBackground)
        .onAppear { isNameFieldFocused = true }
        .alert("Notifications Are Off", isPresented: $isShowingNotificationDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
                hasCompletedOnboarding = true
            }
            Button("Continue Anyway", role: .cancel) {
                hasCompletedOnboarding = true
            }
        } message: {
            Text("Crier+ won't be able to ring your reminders until notifications are allowed. You can turn this on later in Settings.")
        }
    }

    private func continueOnboarding() {
        let trimmed = trimmedName
        guard !trimmed.isEmpty, !isContinuing else { return }
        storedUserName = trimmed
        isContinuing = true

        Task {
            let isAuthorized = (try? await notificationService.requestAuthorization()) ?? false
            // Alarm access is the primary delivery path when granted, but a denial isn't fatal —
            // the notification path above still rings reminders, so this is requested opportunistically
            // without blocking onboarding the way a notification denial does.
            _ = try? await alarmService.requestAuthorization()
            try? await audioService.speakPreview(
                "Hi \(trimmed)! I'm Crier. I'll say your reminders out loud, right when you need them."
            )
            if isAuthorized {
                hasCompletedOnboarding = true
            } else {
                isContinuing = false
                isShowingNotificationDeniedAlert = true
            }
        }
    }
}

#Preview {
    OnboardingView()
}
