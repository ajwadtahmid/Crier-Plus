import SwiftUI

/// Weekday numbers use `Calendar`'s 1-based convention (1 = Sunday ... 7 = Saturday).
struct CustomDaySelector: View {
    @Binding var selectedDays: Set<Int>

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(1...7, id: \.self) { day in
                dayButton(for: day)
            }
        }
    }

    private func dayButton(for day: Int) -> some View {
        let isSelected = selectedDays.contains(day)
        let shortSymbol = calendar.veryShortWeekdaySymbols[day - 1]
        let fullSymbol = calendar.weekdaySymbols[day - 1]

        return Button {
            if isSelected {
                selectedDays.remove(day)
            } else {
                selectedDays.insert(day)
            }
        } label: {
            Text(shortSymbol)
                .font(Theme.Typography.caption)
                .foregroundStyle(isSelected ? .white : Color.appTextPrimary)
                .frame(minWidth: Theme.Layout.minimumTapTarget, minHeight: Theme.Layout.minimumTapTarget)
                .background(isSelected ? Color.appAccent : Color.appSecondaryBackground)
                .clipShape(Circle())
        }
        .accessibilityLabel(fullSymbol)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    @Previewable @State var selectedDays: Set<Int> = [2, 4]
    return CustomDaySelector(selectedDays: $selectedDays)
        .padding()
}
