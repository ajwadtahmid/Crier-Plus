import SwiftUI

enum RootDestination: Equatable {
    case onboarding
    case main

    init(hasCompletedOnboarding: Bool) {
        self = hasCompletedOnboarding ? .main : .onboarding
    }
}

struct RootView: View {
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding: Bool = false

    var body: some View {
        switch RootDestination(hasCompletedOnboarding: hasCompletedOnboarding) {
        case .onboarding:
            OnboardingView()
        case .main:
            ReminderListView()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Reminder.self, inMemory: true)
}
