
import SwiftUI
import SwiftData
import AVFoundation

struct BulkLocationAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("openAIKey") private var openAIKey = ""
    
    let parentLocation: Location
    
    @State private var locationsText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioFileURL: URL?
    
    // Permission states
    @State private var showMicPermissionAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter sub-locations (one per line)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextEditor(text: $locationsText)
                            .frame(minHeight: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
                
                if !openAIKey.isEmpty {
                    Section("Voice Input") {
                        HStack {
                            Button(action: toggleRecording) {
                                HStack {
                                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(isRecording ? .red : .blue)
                                    Text(isRecording ? "Stop Recording" : "Start Recording")
                                }
                            }
                            .disabled(isProcessing)
                            
                            Spacer()
                            
                            if isRecording {
                                Text("Recording...")
                                    .foregroundStyle(.secondary)
                                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: isRecording)
                            }
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Multiple Sub-Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Sub-Locations") {
                        addSubLocations()
                    }
                    .disabled(locationsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                }
            }
            .overlay {
                if isProcessing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Processing...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                }
            }
            .alert("Microphone Permission Required", isPresented: $showMicPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable microphone access in Settings to use voice input.")
            }
        }
    }
    
    private func addSubLocations() {
        let lines = locationsText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        for line in lines {
            let location = Location(name: line, parent: parentLocation)
            modelContext.insert(location)
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save locations: \(error.localizedDescription)"
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            checkMicrophonePermission { granted in
                if granted {
                    startRecording()
                } else {
                    showMicPermissionAlert = true
                }
            }
        }
    }
    
    private func checkMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        @unknown default:
            completion(false)
        }
    }
    
    private func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
            audioFileURL = audioFilename
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecording = true
            
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        if let url = audioFileURL {
            transcribeAudio(url: url)
        }
    }
    
    private func transcribeAudio(url: URL) {
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let audioData = try Data(contentsOf: url)
                
                // Create form data
                let boundary = UUID().uuidString
                var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
                request.httpMethod = "POST"
                request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                
                var body = Data()
                
                // Add model parameter
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
                body.append("whisper-1\r\n".data(using: .utf8)!)
                
                // Add audio file
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
                body.append(audioData)
                body.append("\r\n".data(using: .utf8)!)
                
                body.append("--\(boundary)--\r\n".data(using: .utf8)!)
                
                request.httpBody = body
                
                let (data, _) = try await URLSession.shared.data(for: request)
                let response = try JSONDecoder().decode(WhisperResponse.self, from: data)
                
                // Process with GPT-4
                await processWithGPT(transcription: response.text)
                
                // Clean up audio file
                try? FileManager.default.removeItem(at: url)
                
            } catch {
                await MainActor.run {
                    errorMessage = "Transcription failed: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
    
    private func processWithGPT(transcription: String) async {
        do {
            var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let messages = [
                ["role": "system", "content": "You are a helpful assistant that processes voice transcriptions into lists. Extract items from the transcription and return them as a simple list, one item per line, in title case. Do not use bulletpoints or a numbered list. Only return the items, no explanations or commentary."],
                ["role": "user", "content": "Process this transcription into a list of sub-locations: \(transcription)"]
            ]
            
            let body = [
                "model": "gpt-4",
                "messages": messages,
                "temperature": 0.3
            ] as [String : Any]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(GPTResponse.self, from: data)
            
            if let content = response.choices.first?.message.content {
                await MainActor.run {
                    locationsText = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    isProcessing = false
                }
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "GPT processing failed: \(error.localizedDescription)"
                isProcessing = false
            }
        }
    }
}
