import SwiftUI

struct SettingsView: View {
    @AppStorage("openAIKey") private var openAIKey = ""
    @AppStorage("reviewExpirationDays") private var reviewExpirationDays = 30
    @Environment(\.dismiss) private var dismiss
    @State private var showingAPIKey = false
    
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
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}