import SwiftUI

struct AlarmRingView: View {
    let reminderTitle: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color("Primary"))
                    .symbolEffect(.variableColor.iterative)
                    .accessibilityHidden(true)

                Text(reminderTitle)
                    .font(.system(size: 28, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDismiss()
                }) {
                    Text("Dismiss")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color("Primary"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(ScaleFeedbackButtonStyle())
                .accessibilityLabel("Dismiss alarm for \(reminderTitle)")
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
    }
}
