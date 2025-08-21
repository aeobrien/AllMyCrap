import SwiftUI
import SwiftData

struct ItemEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    var item: Item?
    var location: Location

    // MARK: - State
    @State private var name = ""
    @State private var selectedTags: [Tag] = []
    @State private var showingNewTag = false
    @State private var newTagName = ""
    @State private var newTagColor = Color.blue
    @Query private var allTags: [Tag]
    @State private var tagToEdit: Tag?
    @State private var editingTagName = ""
    @State private var showDeleteAlert = false
    @State private var tagToDelete: Tag?

    /// When non-nil this triggers the duplicate-warning sheet.
    @State private var duplicatePayload: DuplicatePayload?

    struct DuplicatePayload: Identifiable {
        let id = UUID()
        let stubs: [ItemStub]
    }

    @Query private var allItems: [Item]

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                TextField("Item Name", text: $name)
                
                Section("Tags") {
                    // Available tags to select from
                    ForEach(allTags.sorted { $0.name < $1.name }) { tag in
                        HStack {
                            Circle()
                                .fill(Color(hex: tag.color) ?? .blue)
                                .frame(width: 20, height: 20)
                            Text(tag.name)
                            Spacer()
                            if selectedTags.contains(where: { $0.id == tag.id }) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
                                selectedTags.remove(at: index)
                            } else {
                                selectedTags.append(tag)
                            }
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                tagToDelete = tag
                                showDeleteAlert = true
                            }
                            Button("Edit") {
                                tagToEdit = tag
                                editingTagName = tag.name
                            }
                            .tint(.blue)
                        }
                    }
                    
                    Button(action: { showingNewTag = true }) {
                        Label("Create New Tag", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle(item == nil ? "Add Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { checkForDuplicates() }
                        .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let item {
                    name = item.name
                    selectedTags = item.tags
                }
            }
            // ───────── Duplicate sheet ─────────
            .sheet(item: $duplicatePayload) { payload in
                NavigationStack {
                    DuplicateListView(
                        possibleDuplicates: payload.stubs,
                        onCancel:  { duplicatePayload = nil },
                        onSaveAnyway: {
                            save()
                            duplicatePayload = nil
                        })
                }
            }
            .sheet(isPresented: $showingNewTag) {
                NavigationStack {
                    Form {
                        TextField("Tag Name", text: $newTagName)
                        ColorPicker("Color", selection: $newTagColor)
                    }
                    .navigationTitle("New Tag")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                newTagName = ""
                                showingNewTag = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                let tag = Tag(name: newTagName, color: newTagColor.toHex())
                                modelContext.insert(tag)
                                selectedTags.append(tag)
                                newTagName = ""
                                showingNewTag = false
                            }
                            .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .sheet(item: $tagToEdit) { tag in
                NavigationStack {
                    Form {
                        TextField("Tag Name", text: $editingTagName)
                    }
                    .navigationTitle("Edit Tag")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                tagToEdit = nil
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                if let tagToEdit = tagToEdit {
                                    tagToEdit.name = editingTagName
                                    do {
                                        try modelContext.save()
                                    } catch {
                                        print("Failed to save tag: \(error)")
                                    }
                                }
                                tagToEdit = nil
                            }
                            .disabled(editingTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .alert("Delete Tag", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let tag = tagToDelete {
                        // Remove tag from all items
                        for item in tag.items {
                            item.tags.removeAll { $0.id == tag.id }
                        }
                        // Remove from selected tags if present
                        selectedTags.removeAll { $0.id == tag.id }
                        modelContext.delete(tag)
                        do {
                            try modelContext.save()
                        } catch {
                            print("Failed to delete tag: \(error)")
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let tag = tagToDelete {
                    Text("This will remove the '\(tag.name)' tag from \(tag.items.count) item(s). This action cannot be undone.")
                }
            }
        }
    }

    // MARK: - Duplicate logic
    private func checkForDuplicates() {
        let comparison = allItems.filter { other in
            guard let item else { return true }
            return other.id != item.id
        }

        let nameLower = name.lowercased()
        let matches = comparison.filter {
            similarity(between: nameLower, and: $0.name.lowercased()) >= 0.8
        }

        if !matches.isEmpty {
            duplicatePayload = .init(stubs: matches.map {
                ItemStub(id: $0.id,
                         name: $0.name,
                         locationPath: locationPath(for: $0.location))
            })
        } else {
            save()
        }
    }

    // MARK: - Helpers
    private func save() {
        if let item {
            item.name = name
            // Remove item from old tags
            for tag in item.tags {
                tag.items.removeAll { $0.id == item.id }
            }
            // Add item to new tags
            item.tags = selectedTags
            for tag in selectedTags {
                if !tag.items.contains(where: { $0.id == item.id }) {
                    tag.items.append(item)
                }
            }
        } else {
            let newItem = Item(name: name, location: location)
            newItem.tags = selectedTags
            modelContext.insert(newItem)
            // Add the new item to each selected tag
            for tag in selectedTags {
                tag.items.append(newItem)
            }
        }
        dismiss()
    }

    private func locationPath(for loc: Location?) -> String {
        guard let loc else { return "(unknown location)" }
        var parts = [loc.name]
        var current = loc.parent
        while let next = current { parts.append(next.name); current = next.parent }
        return parts.reversed().joined(separator: " › ")
    }
    // Levenshtein similarity
    private func similarity(between a: String, and b: String) -> Double {
        let distance = levenshtein(a, b)
        let maxLength = max(a.count, b.count)
        return maxLength == 0 ? 1.0 : 1.0 - (Double(distance) / Double(maxLength))
    }

    private func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        var dp = Array(repeating: Array(repeating: 0, count: bChars.count + 1), count: aChars.count + 1)

        for i in 0...aChars.count { dp[i][0] = i }
        for j in 0...bChars.count { dp[0][j] = j }

        for i in 1...aChars.count {
            for j in 1...bChars.count {
                if aChars[i-1] == bChars[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = min(
                        dp[i-1][j] + 1,
                        dp[i][j-1] + 1,
                        dp[i-1][j-1] + 1
                    )
                }
            }
        }
        return dp[aChars.count][bChars.count]
    }
}

struct DuplicateListView: View {
    let possibleDuplicates: [ItemStub]
    let onCancel: () -> Void
    let onSaveAnyway: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("We found items with similar names:")
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if possibleDuplicates.isEmpty {
                        Text("⚠️ This should not happen — no duplicates passed in.")
                            .foregroundColor(.red)
                    } else {
                        ForEach(possibleDuplicates) { dupe in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dupe.name)
                                    .fontWeight(.medium)
                                Text(dupe.locationPath)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Spacer()

            HStack {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                Spacer()
                Button("Save Anyway", role: .destructive) {
                    onSaveAnyway()
                }
            }
            .padding(.top)
        }
        .padding()
        .navigationTitle("Possible Duplicates")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            print("🟢 DuplicateListView appeared with \(possibleDuplicates.count) items.")
        }
    }
}


struct ItemStub: Identifiable {
    var id: UUID
    var name: String
    var locationPath: String
}
