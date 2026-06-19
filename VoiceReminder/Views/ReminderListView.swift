import SwiftUI
import SwiftData

struct ReminderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Reminder.scheduledTime) private var reminders: [Reminder]

    @State private var showingForm = false
    @State private var selectedReminder: Reminder?
    @State private var errorToast: String?
    @State private var reminderToDelete: Reminder?

    var body: some View {
        NavigationStack {
            Group {
                if reminders.isEmpty {
                    emptyState
                } else {
                    reminderList
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showingForm = true
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("New Reminder")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .frame(height: 48)
                        .background(Color("Primary"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(ScaleFeedbackButtonStyle())
                }
            }
            .sheet(isPresented: $showingForm) {
                ReminderFormView()
            }
            .sheet(item: $selectedReminder) { reminder in
                ReminderFormView(existingReminder: reminder)
            }
            .alert("Delete reminder?", isPresented: Binding(
                get: { reminderToDelete != nil },
                set: { if !$0 { reminderToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { reminderToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let r = reminderToDelete { deleteReminder(r) }
                }
            }
            .overlay(alignment: .top) {
                if let toast = errorToast {
                    Text(toast)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color("Destructive"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 48))
                .foregroundStyle(Color("TextSecondary"))
                .accessibilityHidden(true)
            Text("No reminders yet")
                .font(.system(size: 28, weight: .semibold))
            Text("Create one to get started")
                .font(.system(size: 16))
                .foregroundStyle(Color("TextSecondary"))
        }
    }

    private var reminderList: some View {
        List {
            ForEach(reminders) { reminder in
                reminderRow(reminder)
                    .listRowBackground(Color("SecondaryBackground"))
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 4)
                    .onTapGesture { selectedReminder = reminder }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            reminderToDelete = reminder
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }

    private func reminderRow(_ reminder: Reminder) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { reminder.isActive },
                set: { newValue in toggleReminder(reminder, active: newValue) }
            ))
            .labelsHidden()
            .accessibilityLabel("\(reminder.isActive ? "Disable" : "Enable") \(reminder.title)")
            .onChange(of: reminder.isActive) { _, _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("TextPrimary"))

                Text(formattedTime(reminder.scheduledTime))
                    .font(.system(size: 14))
                    .foregroundStyle(Color("TextSecondary"))

                if reminder.repeatPattern != .none {
                    Text(reminder.repeatPattern.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(Color("TextSecondary"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color("Border").opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(minHeight: 56)
        .background(Color("SecondaryBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }

    private func toggleReminder(_ reminder: Reminder, active: Bool) {
        reminder.isActive = active
        Task {
            do {
                if active {
                    try await NotificationService.shared.schedule(reminder)
                } else {
                    NotificationService.shared.cancel(reminder.id)
                }
            } catch {
                await MainActor.run {
                    reminder.isActive = !active
                    showError("Failed to \(active ? "enable" : "disable") reminder")
                }
            }
        }
    }

    private func deleteReminder(_ reminder: Reminder) {
        NotificationService.shared.cancel(reminder.id)
        AudioGenerationService().deleteAudio(at: reminder.audioFilePath)
        withAnimation(.easeInOut(duration: 0.2)) { modelContext.delete(reminder) }
        reminderToDelete = nil
    }

    private func showError(_ message: String) {
        withAnimation { errorToast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { errorToast = nil }
        }
    }
}
