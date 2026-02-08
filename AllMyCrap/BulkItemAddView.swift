import SwiftUI
import SwiftData
import AVFoundation

struct BulkItemAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("openAIKey") private var openAIKey = ""
    @AppStorage("bulkItemPrompt") private var bulkItemPrompt = """
Parse the text below and return a JSON array of standardised item name strings. Output ONLY the JSON array.
FORMAT: Base Name - form, size, colour, material, variant (count)
RULES
* Base Name: Title Case; no articles; prefer the thing over brand. If brand = identity (e.g., "WD-40"), keep as Base Name; else put brand in variant.
* Attributes: use this order exactly → form, size, colour, material, variant. Use singular nouns and lower case for attributes. Omit empty fields.
* Count: add "(n)" ONLY if n>1 for identical items mentioned; else omit.
* Packs vs sets: retail pack → form=pack with pack size in size (e.g., "24" or "24 pcs"); grouped tools → form=set or pair.
* Normalisation: big/huge→large; tiny/little→small; metric units (ml/L, g/kg, cm/m); combine dimensions as "WxH cm"; cables in metres (e.g., "2m").
* Synonyms: wire/lead→cable; bottle/jar/tub/tube/box/packet/sachet/bag/roll/sheet/cable/adapter/charger/bulb/battery/book/folder/keyring/case/tool/set/pair/can/spray/cloth/filter.
* Disambiguators (optional): if present, append one tag at end in square brackets: [open] [sealed] [expired yyyy-mm] [spare] [fragile].
* Punctuation: " - " between Base Name and attributes; attributes separated by ", "; no commas in Base Name.
* Ignore: numbering/bullets; any location phrases (e.g., "in/on/at/under/inside/next to/by …"), room/container names, and directions like "left/right/top/bottom" when they describe placement not the item.
* Books: Some items are books and may contain numbers, descriptors/colours which throw off the above system, please note that books will named in the format "Title by Author", ie. "Dubliners by James Joyce" or "Pygmy by Chuck Palahniuk". Please ignore these entries and return them in that format without making any changes.

EXAMPLE Input: "2 large bottles of sweet almond oil, 3 black 2m USB-C cables, 2 white USB-C to HDMI adapters, a pair of black sunglasses, a Silver Coil Webby Award, a dark brown ukulele, and 3 bottles of E45 moisturiser."
 EXAMPLE Output:
[
"Sweet Almond Oil - bottle, large (2)",
"USB-C Cable - cable, 2m, black (3)",
"USB-C to HDMI Adapter - adapter, white (2)",
"Sunglasses - pair, black",
"Webby Award - trophy, silver, coil",
"Ukulele - instrument, dark brown",
"Moisturiser - bottle, E45 (3)"
]
"""
    @Query private var allTags: [Tag]
    @Query private var allItems: [Item]

    let location: Location

    @State private var itemsText = ""
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioFileURL: URL?
    @State private var parsedItems: [ParsedItem] = []
    @State private var showPreview = false

    // Pipeline state
    @State private var pipelineStage: PipelineStage = .idle
    @State private var transcriptionText: String?
    @State private var gptRawResponse: String?
    @State private var pipelineError: String?

    // Duplicate detection
    @State private var bulkDuplicateGroups: [BulkDuplicateGroup] = []
    @State private var showingBulkDuplicates = false

    // Permission states
    @State private var showMicPermissionAlert = false

    enum PipelineStage {
        case idle
        case recording
        case recorded
        case transcribing
        case transcribed
        case processing
        case processed
        case failed(FailedStage)

        enum FailedStage {
            case transcription
            case processing
            case saving
        }
    }

    private var isRecording: Bool {
        if case .recording = pipelineStage { return true }
        return false
    }

    private var isProcessing: Bool {
        switch pipelineStage {
        case .transcribing, .processing: return true
        default: return false
        }
    }

    private var hasFailed: Bool {
        if case .failed = pipelineStage { return true }
        return false
    }

    struct ParsedItem: Identifiable {
        let id = UUID()
        var name: String
        var tags: [String]
        var plan: ItemPlan?
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter items (one per line)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $itemsText)
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

                        pipelineStatusView
                    }
                }

                if let error = pipelineError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Multiple Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cleanupAudioFile()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Items") {
                        parseItemsForPreview()
                        showPreview = true
                    }
                    .disabled(itemsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                }
            }
            .overlay {
                if isProcessing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(pipelineStageDescription)
                            .font(.subheadline)
                    }
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
            .sheet(isPresented: $showPreview) {
                BulkItemPreviewView(parsedItems: $parsedItems, onConfirm: {
                    checkBulkDuplicates()
                    showPreview = false
                })
            }
            .sheet(isPresented: $showingBulkDuplicates) {
                BulkDuplicateListView(
                    groups: bulkDuplicateGroups,
                    onCancel: { showingBulkDuplicates = false },
                    onSaveAnyway: {
                        showingBulkDuplicates = false
                        addItems()
                    }
                )
            }
        }
    }

    // MARK: - Pipeline Status View

    @ViewBuilder
    private var pipelineStatusView: some View {
        switch pipelineStage {
        case .idle:
            EmptyView()
        case .recording:
            EmptyView()
        case .recorded:
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.green)
                Text("Audio recorded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .transcribing:
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Transcribing audio...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .transcribed:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Transcription complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .processing:
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Processing with GPT...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .processed:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Processing complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .failed(let stage):
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(failedStageDescription(stage))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Retry") {
                    retryFromStage(stage)
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
    }

    private var pipelineStageDescription: String {
        switch pipelineStage {
        case .transcribing: return "Transcribing audio..."
        case .processing: return "Processing with GPT..."
        default: return "Processing..."
        }
    }

    private func failedStageDescription(_ stage: PipelineStage.FailedStage) -> String {
        switch stage {
        case .transcription: return "Transcription failed"
        case .processing: return "GPT processing failed"
        case .saving: return "Save failed"
        }
    }

    // MARK: - Pipeline Control

    private func retryFromStage(_ stage: PipelineStage.FailedStage) {
        pipelineError = nil
        switch stage {
        case .transcription:
            transcribeAudio()
        case .processing:
            guard let text = transcriptionText else {
                pipelineError = "No transcription to retry processing with."
                return
            }
            pipelineStage = .processing
            Task {
                await processTranscription(text)
            }
        case .saving:
            addItems()
        }
    }

    // MARK: - Duplicate Checking

    private func checkBulkDuplicates() {
        let candidates = allItems.map {
            DuplicateCandidate(
                id: $0.id,
                name: $0.name,
                isBook: $0.isBook,
                bookTitle: $0.bookTitle,
                bookAuthor: $0.bookAuthor,
                locationPath: locationPath(for: $0.location)
            )
        }

        var groups: [BulkDuplicateGroup] = []

        for parsed in parsedItems {
            let isBook = parsed.name.range(of: " by ", options: .caseInsensitive) != nil
            var bookTitle: String?
            var bookAuthor: String?

            if isBook, let byRange = parsed.name.range(of: " by ", options: .caseInsensitive) {
                bookTitle = String(parsed.name[..<byRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                bookAuthor = String(parsed.name[byRange.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let matches = DuplicateMatcher.findDuplicates(
                name: parsed.name,
                isBook: isBook,
                bookTitle: bookTitle,
                bookAuthor: bookAuthor,
                candidates: candidates
            )

            if !matches.isEmpty {
                groups.append(BulkDuplicateGroup(
                    newItemName: parsed.name,
                    matches: matches
                ))
            }
        }

        if groups.isEmpty {
            addItems()
        } else {
            bulkDuplicateGroups = groups
            showingBulkDuplicates = true
        }
    }

    private func locationPath(for loc: Location?) -> String {
        guard let loc else { return "(unknown location)" }
        var parts = [loc.name]
        var current = loc.parent
        while let next = current { parts.append(next.name); current = next.parent }
        return parts.reversed().joined(separator: " > ")
    }

    // MARK: - Item Parsing

    private func parseItemsForPreview() {
        parsedItems = []
        let lines = itemsText
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            var itemName = line
            var tags: [String] = []
            var plan: ItemPlan?

            // Extract tags [tag1, tag2]
            if let tagMatch = line.range(of: #"\[([^\]]+)\]"#, options: .regularExpression) {
                let tagString = String(line[tagMatch])
                let tagContent = tagString.dropFirst().dropLast() // Remove [ ]
                tags = tagContent.split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                itemName = itemName.replacingOccurrences(of: String(line[tagMatch]), with: "").trimmingCharacters(in: .whitespaces)
            }

            // Extract plan {Plan}
            if let planMatch = line.range(of: #"\{([^\}]+)\}"#, options: .regularExpression) {
                let planString = String(line[planMatch])
                let planContent = planString.dropFirst().dropLast() // Remove { }
                plan = ItemPlan.allCases.first { $0.rawValue.lowercased() == planContent.lowercased() }
                itemName = itemName.replacingOccurrences(of: String(line[planMatch]), with: "").trimmingCharacters(in: .whitespaces)
            }

            parsedItems.append(ParsedItem(name: itemName, tags: tags, plan: plan))
        }
    }

    // MARK: - Save Items

    private func addItems() {
        do {
            for parsedItem in parsedItems {
                // Check if this is a book (contains " by " pattern)
                let item: Item
                if let byRange = parsedItem.name.range(of: " by ", options: .caseInsensitive) {
                    let title = String(parsedItem.name[..<byRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let author = String(parsedItem.name[byRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

                    if !title.isEmpty && !author.isEmpty {
                        item = Item(title: title, author: author, location: location)
                        print("📚 Detected book: \(title) by \(author)")
                    } else {
                        item = Item(name: parsedItem.name, location: location)
                    }
                } else {
                    item = Item(name: parsedItem.name, location: location)
                }

                item.plan = parsedItem.plan

                // Add tags
                for tagName in parsedItem.tags {
                    let trimmedTagName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedTagName.isEmpty else { continue }

                    if let existingTag = allTags.first(where: { $0.name.lowercased() == trimmedTagName.lowercased() }) {
                        if !item.tags.contains(where: { $0.id == existingTag.id }) {
                            item.tags.append(existingTag)
                            existingTag.items.append(item)
                        }
                    } else {
                        let sessionTags = modelContext.insertedModelsArray.compactMap { $0 as? Tag }
                        if let sessionTag = sessionTags.first(where: { $0.name.lowercased() == trimmedTagName.lowercased() }) {
                            if !item.tags.contains(where: { $0.id == sessionTag.id }) {
                                item.tags.append(sessionTag)
                                sessionTag.items.append(item)
                            }
                        } else {
                            let newTag = Tag(name: trimmedTagName, color: "#007AFF")
                            assert(newTag.id != nil, "Tag ID should not be nil")
                            assert(!newTag.name.isEmpty, "Tag name should not be empty")
                            assert(!newTag.color.isEmpty, "Tag color should not be empty")
                            modelContext.insert(newTag)
                            item.tags.append(newTag)
                            newTag.items.append(item)
                        }
                    }
                }

                modelContext.insert(item)
            }

            try modelContext.save()
            cleanupAudioFile()
            dismiss()
        } catch {
            pipelineError = "Failed to save items: \(error.localizedDescription)"
            pipelineStage = .failed(.saving)
            print("Error saving items: \(error)")
        }
    }

    // MARK: - Recording

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
            pipelineStage = .recording

        } catch {
            pipelineError = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        pipelineStage = .recorded

        // Auto-chain to transcription
        transcribeAudio()
    }

    // MARK: - Transcription

    private func transcribeAudio() {
        guard let url = audioFileURL else {
            pipelineError = "No audio file to transcribe."
            pipelineStage = .failed(.transcription)
            return
        }

        pipelineStage = .transcribing
        pipelineError = nil

        Task {
            do {
                let audioData = try Data(contentsOf: url)

                let boundary = UUID().uuidString
                var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
                request.httpMethod = "POST"
                request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

                var body = Data()

                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
                body.append("whisper-1\r\n".data(using: .utf8)!)

                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
                body.append(audioData)
                body.append("\r\n".data(using: .utf8)!)

                body.append("--\(boundary)--\r\n".data(using: .utf8)!)

                request.httpBody = body

                let (data, _) = try await URLSession.shared.data(for: request)
                let response = try JSONDecoder().decode(WhisperResponse.self, from: data)

                await MainActor.run {
                    transcriptionText = response.text
                    pipelineStage = .transcribed

                    // Auto-chain to GPT processing
                    pipelineStage = .processing
                }

                await processTranscription(response.text)

            } catch {
                await MainActor.run {
                    pipelineError = "Transcription failed: \(error.localizedDescription)"
                    pipelineStage = .failed(.transcription)
                }
            }
        }
    }

    // MARK: - GPT Processing

    private func processTranscription(_ transcription: String) async {
        do {
            var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let existingTags = allTags.map { $0.name }.joined(separator: ", ")
            let systemPrompt = """
            You are a helpful assistant that processes voice transcriptions into structured lists. Extract items from the transcription and return them as a simple list, one item per line.

            Format:
            Item Name [tag1, tag2] {plan}

            Tags (in square brackets): If the user mentions tags, match them to these existing tags: \(existingTags). If they mention a tag name that's similar, use the existing tag. If it's clearly a new tag, include it as stated.

            Plans (in curly braces): The user may indicate what to do with items. Map their intent to one of these exact values:
            - {Keep} - for items to keep/retain
            - {Throw Away} - for items to discard/trash/throw out
            - {Sell} - for items to sell
            - {Charity} - for items to donate/give away
            - {Move} - for items to relocate/move elsewhere

            Examples:
            - "Red box with memories, keep it" → Red Box [Memories] {Keep}
            - "Old phone to sell" → Old Phone {Sell}
            - "Tools box, tag as tools, move to garage" → Tools Box [Tools] {Move}

            Only include tags and plans if explicitly mentioned. Do not add them if not stated by the user.
            """

            let messages = [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": bulkItemPrompt + "\n\nTranscription: \(transcription)"]
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
                    gptRawResponse = content
                    parseGPTResponse(content)
                    pipelineStage = .processed
                }
            }

        } catch {
            await MainActor.run {
                pipelineError = "GPT processing failed: \(error.localizedDescription)"
                pipelineStage = .failed(.processing)
            }
        }
    }

    private func parseGPTResponse(_ content: String) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        print("🔵 BulkItemAdd - Received content from OpenAI:")
        print(trimmedContent)

        if trimmedContent.hasPrefix("[") && trimmedContent.hasSuffix("]") {
            print("🔵 Detected JSON array format")

            let cleaned = trimmedContent
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let jsonData = cleaned.data(using: .utf8) {
                do {
                    if let items = try JSONSerialization.jsonObject(with: jsonData) as? [String] {
                        print("✅ Successfully parsed \(items.count) items from JSON array")
                        itemsText = items.joined(separator: "\n")
                    } else {
                        print("❌ JSON parsing succeeded but not a string array")
                        itemsText = trimmedContent
                    }
                } catch {
                    print("❌ JSON parsing failed: \(error)")
                    itemsText = trimmedContent
                }
            }
        } else {
            print("🔵 Using as plain text (not JSON array)")
            itemsText = trimmedContent
        }

        parseItemsForPreview()
    }

    // MARK: - Audio Cleanup

    private func cleanupAudioFile() {
        guard let url = audioFileURL else { return }
        try? FileManager.default.removeItem(at: url)
        audioFileURL = nil
    }
}

// Response structures
struct WhisperResponse: Codable {
    let text: String
}

struct GPTResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}
