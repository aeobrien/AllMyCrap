import SwiftUI
import SwiftData

struct DuplicateReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Item> { $0.isArchived == false }) private var allItems: [Item]
    @Query private var exclusions: [DuplicateExclusion]

    @State private var duplicatePairs: [DuplicatePair] = []
    @State private var currentPairIndex = 0
    @State private var isScanning = true
    @State private var scanProgress: String = "Preparing..."
    @State private var scanFraction: Double = 0
    @State private var editingItem: Item?

    struct DuplicatePair: Identifiable {
        let id = UUID()
        let item1: Item
        let item2: Item
        let score: Double
    }

    /// Lightweight value type for background comparison (no SwiftData references).
    private struct ScanItem: Sendable {
        let id: UUID
        let name: String
        let normalizedName: String
        let lowercaseName: String
        let isBook: Bool
        let bookTitle: String?
        let bookAuthor: String?
    }

    private struct ScanResult: Sendable {
        let id1: UUID
        let id2: UUID
        let score: Double
    }

    private var currentPair: DuplicatePair? {
        guard currentPairIndex < duplicatePairs.count else { return nil }
        return duplicatePairs[currentPairIndex]
    }

    var body: some View {
        NavigationStack {
            if isScanning {
                VStack(spacing: 16) {
                    if scanFraction > 0 {
                        ProgressView(value: scanFraction)
                            .progressViewStyle(.linear)
                            .frame(width: 200)
                    } else {
                        ProgressView()
                    }
                    Text("Scanning for duplicates...")
                        .foregroundColor(.secondary)
                    Text(scanProgress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .task { await scanForDuplicates() }
            } else if duplicatePairs.isEmpty {
                ContentUnavailableView(
                    "No Duplicates Found",
                    systemImage: "checkmark.circle.fill",
                    description: Text("All items look unique!")
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            } else if let pair = currentPair {
                pairReviewView(pair)
            } else {
                // Finished all pairs
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text("Review Complete!")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("All duplicate pairs have been reviewed.")
                        .foregroundColor(.secondary)
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Pair Review View

    @ViewBuilder
    private func pairReviewView(_ pair: DuplicatePair) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Progress
                HStack {
                    Text("Pair \(currentPairIndex + 1) of \(duplicatePairs.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(pair.score * 100))% similar")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                }
                .padding(.horizontal)

                // Side by side items
                HStack(alignment: .top, spacing: 12) {
                    itemCard(pair.item1, label: "Item A")
                    itemCard(pair.item2, label: "Item B")
                }
                .padding(.horizontal)

                Divider()

                // Actions
                VStack(spacing: 10) {
                    Button {
                        markNotDuplicate(pair)
                    } label: {
                        Label("Not a Duplicate", systemImage: "hand.thumbsdown")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)

                    HStack(spacing: 12) {
                        Button {
                            deleteItem(pair.item1)
                        } label: {
                            Label("Delete A", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)

                        Button {
                            deleteItem(pair.item2)
                        } label: {
                            Label("Delete B", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }

                    HStack(spacing: 12) {
                        Button {
                            editingItem = pair.item1
                        } label: {
                            Label("Edit A", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            editingItem = pair.item2
                        } label: {
                            Label("Edit B", systemImage: "pencil")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        skipPair()
                    } label: {
                        Text("Skip")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Find Duplicates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: $editingItem) { item in
            if let loc = item.location {
                ItemEditView(item: item, location: loc)
            }
        }
        .onChange(of: editingItem) { _, newValue in
            if newValue == nil {
                // Re-scan after edit in case names changed
                rescanAfterEdit()
            }
        }
    }

    @ViewBuilder
    private func itemCard(_ item: Item, label: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Text(item.displayName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(3)

            if let location = item.location {
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.caption2)
                    Text(locationPath(for: location))
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            if !item.tags.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.caption2)
                    Text(item.tags.map { $0.name }.joined(separator: ", "))
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            if let plan = item.plan {
                HStack(spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.caption2)
                    Text(plan.rawValue)
                        .font(.caption2)
                }
                .foregroundColor(.blue)
            }

            Text("Added \(item.dateAdded, style: .date)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    // MARK: - Actions

    private func markNotDuplicate(_ pair: DuplicatePair) {
        let exclusion = DuplicateExclusion(itemID1: pair.item1.id, itemID2: pair.item2.id)
        modelContext.insert(exclusion)
        do {
            try modelContext.save()
        } catch {
            print("Failed to save exclusion: \(error)")
        }
        advanceToNextPair()
    }

    private func deleteItem(_ item: Item) {
        modelContext.delete(item)
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete item: \(error)")
        }
        // Remove all pairs involving this deleted item
        let deletedId = item.id
        duplicatePairs.removeAll { $0.item1.id == deletedId || $0.item2.id == deletedId }
        // Adjust index if needed
        if currentPairIndex >= duplicatePairs.count {
            currentPairIndex = max(0, duplicatePairs.count - 1)
        }
    }

    private func skipPair() {
        advanceToNextPair()
    }

    private func advanceToNextPair() {
        currentPairIndex += 1
    }

    private func rescanAfterEdit() {
        // Quick re-scan: remove pairs that no longer meet threshold
        let itemIDs = Set(allItems.map { $0.id })
        duplicatePairs = duplicatePairs.filter { pair in
            guard itemIDs.contains(pair.item1.id),
                  itemIDs.contains(pair.item2.id) else {
                return false
            }
            let score = DuplicateMatcher.bestSimilarity(between: pair.item1.name, and: pair.item2.name)
            return score >= 0.75
        }
        if currentPairIndex >= duplicatePairs.count {
            currentPairIndex = max(0, duplicatePairs.count - 1)
        }
    }

    // MARK: - Scanning

    private func scanForDuplicates() async {
        // 1. Extract lightweight data on the main thread, pre-normalizing strings
        let scanItems: [ScanItem] = allItems.map { item in
            ScanItem(
                id: item.id,
                name: item.name,
                normalizedName: DuplicateMatcher.normalize(item.name),
                lowercaseName: item.name.lowercased(),
                isBook: item.isBook,
                bookTitle: item.bookTitle,
                bookAuthor: item.bookAuthor
            )
        }

        // Build exclusion set for O(1) lookups (canonical key = "smallerUUID:largerUUID")
        let excludedPairs: Set<String> = Set(exclusions.map { exclusion in
            let a = exclusion.itemID1.uuidString
            let b = exclusion.itemID2.uuidString
            return a < b ? "\(a):\(b)" : "\(b):\(a)"
        })

        let count = scanItems.count
        // Total pairs = n*(n-1)/2
        let totalPairs = count > 1 ? (count * (count - 1)) / 2 : 0
        scanProgress = "Comparing \(count) items (\(totalPairs) pairs)..."

        guard count > 1 else {
            duplicatePairs = []
            currentPairIndex = 0
            isScanning = false
            return
        }

        // 2. Process in batches by outer-loop index, updating progress between batches
        let batchSize = max(1, count / 50) // ~50 progress updates
        var allResults: [ScanResult] = []
        var pairsProcessed = 0

        for batchStart in stride(from: 0, to: count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, count)
            let capturedPairsProcessed = pairsProcessed

            let batchResults: (results: [ScanResult], pairsInBatch: Int) = await Task.detached(priority: .userInitiated) {
                var found: [ScanResult] = []
                var batchPairs = 0

                for i in batchStart..<batchEnd {
                    for j in (i + 1)..<count {
                        batchPairs += 1
                        let a = scanItems[i]
                        let b = scanItems[j]

                        // O(1) exclusion check
                        let keyA = a.id.uuidString
                        let keyB = b.id.uuidString
                        let key = keyA < keyB ? "\(keyA):\(keyB)" : "\(keyB):\(keyA)"
                        if excludedPairs.contains(key) { continue }

                        // Length-based early exit: if lengths differ by >50%, max similarity is low
                        let lenA = a.normalizedName.count
                        let lenB = b.normalizedName.count
                        let maxLen = max(lenA, lenB)
                        if maxLen > 0 {
                            let lenDiff = abs(lenA - lenB)
                            // Levenshtein similarity can't exceed 1 - lenDiff/maxLen
                            let maxPossible = 1.0 - (Double(lenDiff) / Double(maxLen))
                            if maxPossible < 0.75 {
                                // Still check Jaccard (word overlap) which isn't length-dependent
                                let jaccard = DuplicateMatcher.jaccardSimilarity(a.normalizedName, b.normalizedName)
                                if jaccard < 0.75 { continue }
                            }
                        }

                        // Calculate similarity using pre-normalized strings
                        let score: Double
                        if a.isBook && b.isBook,
                           let t1 = a.bookTitle, let a1 = a.bookAuthor {
                            let candidate = DuplicateCandidate(
                                id: b.id, name: b.name,
                                isBook: b.isBook, bookTitle: b.bookTitle,
                                bookAuthor: b.bookAuthor, locationPath: ""
                            )
                            let matches = DuplicateMatcher.findDuplicates(
                                name: a.name, isBook: true,
                                bookTitle: t1, bookAuthor: a1,
                                candidates: [candidate], threshold: 0.75
                            )
                            score = matches.first?.score ?? 0
                        } else {
                            // Use pre-normalized/lowercased strings directly
                            let s1 = DuplicateMatcher.levenshteinSimilarity(a.normalizedName, b.normalizedName)
                            let s2 = DuplicateMatcher.levenshteinSimilarity(a.lowercaseName, b.lowercaseName)
                            let s3 = DuplicateMatcher.jaccardSimilarity(a.normalizedName, b.normalizedName)
                            score = max(s1, s2, s3)
                        }

                        if score >= 0.75 {
                            found.append(ScanResult(id1: a.id, id2: b.id, score: score))
                        }
                    }
                }

                return (found, batchPairs)
            }.value

            allResults.append(contentsOf: batchResults.results)
            pairsProcessed = capturedPairsProcessed + batchResults.pairsInBatch

            // Update progress on main thread
            let fraction = totalPairs > 0 ? Double(pairsProcessed) / Double(totalPairs) : 0
            scanFraction = fraction
            let pct = Int(fraction * 100)
            scanProgress = "\(pct)% — \(pairsProcessed) of \(totalPairs) pairs checked, \(allResults.count) found"
        }

        // 3. Sort by score and map back to Item objects
        allResults.sort { $0.score > $1.score }

        let itemMap: [UUID: Item] = Dictionary(uniqueKeysWithValues: allItems.map { ($0.id, $0) })
        var pairs: [DuplicatePair] = []
        for result in allResults {
            if let item1 = itemMap[result.id1], let item2 = itemMap[result.id2] {
                pairs.append(DuplicatePair(item1: item1, item2: item2, score: result.score))
            }
        }

        duplicatePairs = pairs
        currentPairIndex = 0
        isScanning = false
    }

    // MARK: - Helpers

    private func locationPath(for location: Location) -> String {
        var parts: [String] = []
        var current: Location? = location
        while let loc = current {
            parts.insert(loc.name, at: 0)
            current = loc.parent
        }
        return parts.joined(separator: " > ")
    }
}
