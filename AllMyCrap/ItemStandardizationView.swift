import SwiftUI
import SwiftData

struct ItemStandardizationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("openAIKey") private var openAIKey = ""
    @AppStorage("standardizationPrompt") private var standardizationPrompt = """
Parse the text below and return a JSON object (NOT an array) with standardised item names. Each input line is prefixed with an index [n]. Your response must maintain these indices.

OUTPUT FORMAT MUST BE A JSON OBJECT: {"1": "standardized name", "2": "standardized name", ...}
DO NOT RETURN A JSON ARRAY like ["item1", "item2"]

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

EXAMPLE Input:
[1] 2 large bottles of sweet almond oil
[2] 3 black 2m USB-C cables
[3] a pair of black sunglasses

EXAMPLE Output:
{
  "1": "Sweet Almond Oil - bottle, large (2)",
  "2": "USB-C Cable - cable, 2m, black (3)",
  "3": "Sunglasses - pair, black"
}
"""
    
    @Query(filter: #Predicate<Item> { $0.isBook == false }) private var items: [Item]
    
    @State private var itemsToStandardize: [ItemUpdate] = []
    @State private var selectedItems: Set<UUID> = []
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var processedCount = 0
    @State private var totalCount = 0
    @State private var batchSize = 10
    @State private var autoProcess = false
    
    struct ItemUpdate: Identifiable {
        let id = UUID()
        let item: Item
        let originalName: String
        var standardizedName: String
        var isSelected: Bool = true
        var status: Status = .pending
        var batchIndex: Int = 0  // Track position in batch
        
        enum Status {
            case pending, processing, completed, failed, skipped
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if itemsToStandardize.isEmpty && !isProcessing {
                    ContentUnavailableView(
                        "Scanning Items",
                        systemImage: "sparkles",
                        description: Text("Analyzing items for standardization...")
                    )
                    .onAppear {
                        scanItems()
                    }
                } else {
                    List {
                        if !itemsToStandardize.isEmpty {
                            Section {
                                HStack {
                                    Text("\(itemsToStandardize.filter { $0.isSelected }.count) of \(itemsToStandardize.count) items selected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button(itemsToStandardize.allSatisfy { $0.isSelected } ? "Deselect All" : "Select All") {
                                        let selectAll = !itemsToStandardize.allSatisfy { $0.isSelected }
                                        for i in itemsToStandardize.indices {
                                            itemsToStandardize[i].isSelected = selectAll
                                        }
                                    }
                                    .font(.caption)
                                }
                                .padding(.vertical, 4)
                            }
                            
                            Section("Items to Standardize") {
                                ForEach($itemsToStandardize) { $update in
                                    HStack {
                                        Image(systemName: update.isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(update.isSelected ? .blue : .gray)
                                            .onTapGesture {
                                                update.isSelected.toggle()
                                            }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(update.originalName)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .strikethrough(update.status == .completed)
                                            
                                            if update.status == .completed || update.status == .processing {
                                                Text(update.standardizedName)
                                                    .foregroundColor(update.status == .completed ? .green : .blue)
                                            }
                                            
                                            if let location = update.item.location {
                                                Text(locationPath(for: location))
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if update.status == .processing {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else if update.status == .completed {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        } else if update.status == .failed {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    .opacity(update.status == .completed ? 0.6 : 1.0)
                                }
                            }
                            
                            if isProcessing {
                                Section {
                                    HStack {
                                        ProgressView(value: Double(processedCount), total: Double(totalCount))
                                        Text("\(processedCount) / \(totalCount)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        Section("Settings") {
                            Stepper("Batch Size: \(batchSize)", value: $batchSize, in: 5...50, step: 5)
                            Toggle("Auto-process all items", isOn: $autoProcess)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("Standardize Item Names")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !itemsToStandardize.isEmpty && !isProcessing {
                        Button("Standardize") {
                            Task {
                                await standardizeItems()
                            }
                        }
                        .disabled(itemsToStandardize.filter { $0.isSelected }.isEmpty || openAIKey.isEmpty)
                    }
                }
            }
        }
    }
    
    private func scanItems() {
        // Check each item to see if it needs standardization
        for item in items {
            // Skip if it looks like it's already standardized
            if !isAlreadyStandardized(item.name) {
                itemsToStandardize.append(ItemUpdate(
                    item: item,
                    originalName: item.name,
                    standardizedName: item.name,
                    isSelected: true
                ))
            }
        }
        
        // Sort by name for easier review
        itemsToStandardize.sort { $0.originalName < $1.originalName }
    }
    
    private func isAlreadyStandardized(_ name: String) -> Bool {
        // Check if name follows the standardized format
        // Look for pattern: "Base Name - attributes" or "Base Name (count)"
        let hasStandardSeparator = name.contains(" - ")
        let hasCount = name.range(of: #"\(\d+\)$"#, options: .regularExpression) != nil
        
        // Also check for common standardized patterns
        let standardizedPatterns = [
            #"^[A-Z][^,]+ - [a-z]"#,  // Base Name - lowercase attribute
            #"^[A-Z][^,]+ \(\d+\)$"#,  // Base Name (count)
        ]
        
        for pattern in standardizedPatterns {
            if name.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func standardizeItems() async {
        guard !openAIKey.isEmpty else {
            errorMessage = "Please set your OpenAI API key in Settings"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        let selectedItems = itemsToStandardize.filter { $0.isSelected && $0.status != .completed }
        totalCount = selectedItems.count
        processedCount = 0
        
        // Process in batches
        for batchStart in stride(from: 0, to: selectedItems.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, selectedItems.count)
            let batch = Array(selectedItems[batchStart..<batchEnd])
            
            // Create indexed text for each item
            var indexedText = ""
            var indexToItem: [String: ItemUpdate] = [:]
            
            for (index, item) in batch.enumerated() {
                let batchIndex = index + 1
                indexedText += "[\(batchIndex)] \(item.originalName)\n"
                indexToItem[String(batchIndex)] = item
            }
            
            // Mark items as processing
            for item in batch {
                if let index = itemsToStandardize.firstIndex(where: { $0.id == item.id }) {
                    itemsToStandardize[index].status = .processing
                }
            }
            
            // Process with OpenAI
            do {
                print("📤 Sending to OpenAI batch of \(batch.count) items:")
                print(indexedText)
                let standardizedMap = try await processWithOpenAI(indexedText.trimmingCharacters(in: .whitespacesAndNewlines))
                
                // Update items with standardized names using index mapping
                for (indexStr, item) in indexToItem {
                    if let standardizedName = standardizedMap[indexStr],
                       let itemIndex = itemsToStandardize.firstIndex(where: { $0.id == item.id }) {
                        itemsToStandardize[itemIndex].standardizedName = standardizedName
                        itemsToStandardize[itemIndex].status = .completed
                        
                        // Update the actual item
                        item.item.name = standardizedName
                    } else {
                        // Mark as failed if no result found for this index
                        if let itemIndex = itemsToStandardize.firstIndex(where: { $0.id == item.id }) {
                            itemsToStandardize[itemIndex].status = .failed
                        }
                    }
                }
                
                processedCount += batch.count
                
            } catch {
                // Mark batch as failed
                for item in batch {
                    if let index = itemsToStandardize.firstIndex(where: { $0.id == item.id }) {
                        itemsToStandardize[index].status = .failed
                    }
                }
                errorMessage = "Error processing batch: \(error.localizedDescription)"
                
                if !autoProcess {
                    break  // Stop processing on error if not auto-processing
                }
            }
            
            // Small delay between batches to avoid rate limiting
            if batchEnd < selectedItems.count {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
        
        // Save changes
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
        }
        
        isProcessing = false
        
        // Remove completed items from the list
        itemsToStandardize.removeAll { $0.status == .completed }
        
        if itemsToStandardize.isEmpty {
            dismiss()
        }
    }
    
    private func processWithOpenAI(_ text: String) async throws -> [String: String] {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": standardizationPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3,
            "max_tokens": 1000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            print("🔴 OpenAI API Error - Status: \(statusCode)")
            print("🔴 Error body: \(errorBody)")
            throw NSError(domain: "OpenAI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "OpenAI API returned status \(statusCode): \(errorBody)"])
        }
        
        // Debug: Print raw response
        if let rawResponse = String(data: data, encoding: .utf8) {
            print("🟢 OpenAI Raw Response: \(rawResponse)")
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            print("🟡 OpenAI Content: \(content)")
            
            // Clean up the response
            let cleaned = content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("🟡 Cleaned Content: \(cleaned)")
            
            // Parse JSON object (indexed dictionary)
            if let jsonData = cleaned.data(using: .utf8) {
                do {
                    if let items = try JSONSerialization.jsonObject(with: jsonData) as? [String: String] {
                        print("✅ Successfully parsed \(items.count) items")
                        return items
                    } else if let array = try JSONSerialization.jsonObject(with: jsonData) as? [String] {
                        // Fallback: If it's an array, convert to indexed dictionary
                        print("⚠️ Got array instead of object, converting...")
                        var indexedItems: [String: String] = [:]
                        for (index, item) in array.enumerated() {
                            indexedItems[String(index + 1)] = item
                        }
                        return indexedItems
                    } else {
                        print("❌ Parsed JSON but wrong type: \(type(of: try JSONSerialization.jsonObject(with: jsonData)))")
                    }
                } catch {
                    print("❌ JSON Parse Error: \(error)")
                    print("❌ Attempted to parse: \(cleaned)")
                }
            }
        } else {
            print("❌ Failed to extract content from OpenAI response")
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("❌ Full response: \(rawResponse)")
            }
        }
        
        throw NSError(domain: "OpenAI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse OpenAI response - check console for details"])
    }
    
    private func locationPath(for location: Location) -> String {
        var path: [String] = []
        var current: Location? = location
        
        while let loc = current {
            path.insert(loc.name, at: 0)
            current = loc.parent
        }
        
        return path.joined(separator: " > ")
    }
}