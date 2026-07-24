import SwiftUI

struct OnboardingView: View {
    @AppStorage(AppStorageKeys.userName) private var storedUserName: String = ""
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding: Bool = false
    @State private var name: String = ""
    @FocusState private var isNameFieldFocused: Bool

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
                .padding(.horizontal, Theme.Spacing.xl)
                .accessibilityLabel("Your name")

            Button("Continue", action: continueOnboarding)
                .buttonStyle(.borderedProminent)
                .tint(Color.appPrimary)
                .disabled(trimmedName.isEmpty)
                .frame(minHeight: Theme.Layout.minimumTapTarget)
                .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .background(Color.appBackground)
        .onAppear { isNameFieldFocused = true }
    }

    private func continueOnboarding() {
        let trimmed = trimmedName
        guard !trimmed.isEmpty else { return }
        storedUserName = trimmed
        hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingView()
}
