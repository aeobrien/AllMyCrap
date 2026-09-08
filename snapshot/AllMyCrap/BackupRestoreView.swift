import SwiftUI
import SwiftData

struct BackupRestoreView: View {
    @EnvironmentObject var backupManager: BackupManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingRestoreAlert = false
    @State private var selectedBackup: BackupManager.BackupFile?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteAlert = false
    @State private var backupToDelete: BackupManager.BackupFile?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Last Backup")
                        Spacer()
                        if let date = backupManager.lastBackupDate {
                            Text(date, style: .relative)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Never")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: performManualBackup) {
                        HStack {
                            Label("Back Up Now", systemImage: "icloud.and.arrow.up")
                            Spacer()
                            if backupManager.isBackingUp {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(backupManager.isBackingUp || backupManager.isRestoring)
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Backups are automatically created when you open the app and periodically while using it.")
                        .font(.caption)
                }
                
                Section {
                    if backupManager.backups.isEmpty {
                        Text("No backups available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(backupManager.backups) { backup in
                            Button(action: {
                                selectedBackup = backup
                                showingRestoreAlert = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(backup.date, style: .date)
                                            .foregroundColor(.primary)
                                        HStack {
                                            Text(backup.date, style: .time)
                                            Text("•")
                                            Text(backup.formattedSize)
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    backupToDelete = backup
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Available Backups")
                } footer: {
                    if !backupManager.backups.isEmpty {
                        Text("Tap a backup to restore it. This will replace all current data.")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Backup & Restore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Restore Backup?", isPresented: $showingRestoreAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Restore", role: .destructive) {
                    if let backup = selectedBackup {
                        performRestore(from: backup)
                    }
                }
            } message: {
                Text("This will replace all current data with the backup from \(selectedBackup?.date ?? Date(), style: .date). This action cannot be undone.")
            }
            .alert("Delete Backup?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let backup = backupToDelete {
                        deleteBackup(backup)
                    }
                }
            } message: {
                Text("This backup will be permanently deleted.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                backupManager.loadBackups()
            }
            .refreshable {
                backupManager.loadBackups()
            }
        }
    }
    
    private func performManualBackup() {
        Task {
            do {
                try await backupManager.createBackup(modelContext: modelContext)
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func performRestore(from backup: BackupManager.BackupFile) {
        Task {
            do {
                try await backupManager.restoreBackup(from: backup.url, modelContext: modelContext)
                dismiss()
            } catch {
                errorMessage = "Failed to restore backup: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
    
    private func deleteBackup(_ backup: BackupManager.BackupFile) {
        do {
            try backupManager.deleteBackup(backup)
        } catch {
            errorMessage = "Failed to delete backup: \(error.localizedDescription)"
            showingError = true
        }
    }
}