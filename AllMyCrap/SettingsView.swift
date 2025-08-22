import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("openAIKey") private var openAIKey = ""
    @AppStorage("reviewExpirationDays") private var reviewExpirationDays = 30
    @AppStorage("bulkItemPrompt") private var bulkItemPrompt = "Parse this list and return a JSON array of item names. Each item should be on its own line or separated clearly. Remove any numbering, bullets, or unnecessary formatting. Return only the JSON array with no additional text."
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var backupManager: BackupManager
    @State private var showingAPIKey = false
    @State private var showingBackupView = false
    @State private var processingHyphens = false
    @State private var hyphenRemovalResult = ""
    @State private var showingBookDetection = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("OpenAI API Key")
                        Spacer()
                        if showingAPIKey {
                            TextField("sk-...", text: $openAIKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("sk-...", text: $openAIKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        Button(action: { showingAPIKey.toggle() }) {
                            Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("API Configuration")
                } footer: {
                    Text("Your OpenAI API key is stored securely on your device and is only used for voice transcription and processing.")
                        .font(.caption)
                }
                
                Section {
                    Link("Get an API Key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    Link("OpenAI Pricing", destination: URL(string: "https://openai.com/pricing")!)
                } header: {
                    Text("Resources")
                }
                
                Section {
                    Button(action: { showingBackupView = true }) {
                        HStack {
                            Label("Backup & Restore", systemImage: "icloud")
                            Spacer()
                            if let date = backupManager.lastBackupDate {
                                Text(date, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Data Management")
                }
                
                Section {
                    Picker("Auto-unmark reviews after", selection: $reviewExpirationDays) {
                        Text("Never").tag(0)
                        Text("7 days").tag(7)
                        Text("14 days").tag(14)
                        Text("30 days").tag(30)
                        Text("60 days").tag(60)
                        Text("90 days").tag(90)
                        Text("180 days").tag(180)
                        Text("365 days").tag(365)
                    }
                } header: {
                    Text("Review Settings")
                } footer: {
                    Text("Reviewed locations will automatically be marked as unreviewed after the selected period.")
                        .font(.caption)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcription Processing Prompt")
                            .font(.headline)
                        TextEditor(text: $bulkItemPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 100)
                            .padding(4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                } header: {
                    Text("Voice Input Settings")
                } footer: {
                    Text("This prompt is used to process voice transcriptions into item lists.")
                        .font(.caption)
                }
                
                Section {
                    Button(action: removeLeadingHyphens) {
                        HStack {
                            Label("Remove Leading Hyphens", systemImage: "minus.circle")
                            Spacer()
                            if processingHyphens {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(processingHyphens)
                    
                    if !hyphenRemovalResult.isEmpty {
                        Text(hyphenRemovalResult)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: { showingBookDetection = true }) {
                        Label("Detect Books", systemImage: "books.vertical")
                    }
                } header: {
                    Text("Maintenance")
                } footer: {
                    Text("Remove leading hyphens or detect and convert items to books.")
                        .font(.caption)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingBackupView) {
                BackupRestoreView()
                    .environmentObject(backupManager)
            }
            .sheet(isPresented: $showingBookDetection) {
                BookDetectionView()
            }
        }
    }
    
    private func removeLeadingHyphens() {
        processingHyphens = true
        hyphenRemovalResult = ""
        
        Task {
            do {
                let items = try modelContext.fetch(FetchDescriptor<Item>())
                var updatedCount = 0
                
                for item in items {
                    if item.name.hasPrefix("- ") {
                        item.name = String(item.name.dropFirst(2))
                        updatedCount += 1
                    }
                }
                
                if updatedCount > 0 {
                    try modelContext.save()
                }
                
                await MainActor.run {
                    hyphenRemovalResult = "Updated \(updatedCount) item\(updatedCount == 1 ? "" : "s")"
                    processingHyphens = false
                }
            } catch {
                await MainActor.run {
                    hyphenRemovalResult = "Error: \(error.localizedDescription)"
                    processingHyphens = false
                }
            }
        }
    }
}