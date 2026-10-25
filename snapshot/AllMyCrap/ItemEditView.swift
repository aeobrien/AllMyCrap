import SwiftUI
import SwiftData

struct ItemEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    var item: Item?
    var location: Location

    // MARK: - State
    @State private var name = ""
    @State private var isBook = false
    @State private var bookTitle = ""
    @State private var bookAuthor = ""
    @State private var selectedTags: [Tag] = []
    @State private var showingNewTag = false
    @State private var newTagName = ""
    @State private var newTagColor = Color.blue
    @Query private var allTags: [Tag]
    @State private var tagToEdit: Tag?
    @State private var editingTagName = ""
    @State private var showDeleteAlert = false
    @State private var tagToDelete: Tag?
    @State private var showBookSuggestion = false
    @State private var suggestedTitle = ""
    @State private var suggestedAuthor = ""

    /// When non-nil this triggers the duplicate-warning sheet.
    @State private var duplicatePayload: DuplicatePayload?

    struct DuplicatePayload: Identifiable {
        let id = UUID()
        let stubs: [ItemStub]
    }

    @Query(filter: #Predicate<Item> { $0.isArchived == false }) private var allItems: [Item]

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("This is a book", isOn: $isBook)
                    
                    if isBook {
                        TextField("Title", text: $bookTitle)
                        TextField("Author", text: $bookAuthor)
                    } else {
                        TextField("Item Name", text: $name)
                            .onChange(of: name) { oldValue, newValue in
                                checkForBookPattern(in: newValue)
                            }
                    }
                }
                
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
                        .disabled(isBook ? (bookTitle.isEmpty || bookAuthor.isEmpty) : name.isEmpty)
                }
            }
            .onAppear {
                if let item {
                    isBook = item.isBook
                    if item.isBook {
                        bookTitle = item.bookTitle ?? ""
                        bookAuthor = item.bookAuthor ?? ""
                    } else {
                        name = item.name
                    }
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
            // Book suggestion alert
            .alert("Convert to Book?", isPresented: $showBookSuggestion) {
                Button("Convert") {
                    isBook = true
                    bookTitle = suggestedTitle
                    bookAuthor = suggestedAuthor
                    name = ""
                }
                Button("Keep as Item", role: .cancel) { }
            } message: {
                Text("This looks like a book:\n\nTitle: \(suggestedTitle)\nAuthor: \(suggestedAuthor)\n\nWould you like to convert it?")
            }
        }
    }

    // MARK: - Duplicate logic
    private func checkForDuplicates() {
        let candidates = allItems
            .filter { other in
                guard let item else { return true }
                return other.id != item.id
            }
            .map { DuplicateCandidate(
                id: $0.id,
                name: $0.name,
                isBook: $0.isBook,
                bookTitle: $0.bookTitle,
                bookAuthor: $0.bookAuthor,
                locationPath: locationPath(for: $0.location)
            )}

        let checkName = isBook ? "\(bookTitle) by \(bookAuthor)" : name
        let matches = DuplicateMatcher.findDuplicates(
            name: checkName,
            isBook: isBook,
            bookTitle: isBook ? bookTitle : nil,
            bookAuthor: isBook ? bookAuthor : nil,
            candidates: candidates
        )

        if !matches.isEmpty {
            duplicatePayload = .init(stubs: matches.map {
                ItemStub(id: $0.id, name: $0.name, locationPath: $0.locationPath)
            })
        } else {
            save()
        }
    }

    // MARK: - Helpers
    private func save() {
        if let item {
            // Update existing item
            if isBook {
                item.isBook = true
                item.bookTitle = bookTitle
                item.bookAuthor = bookAuthor
                item.name = "\(bookTitle) by \(bookAuthor)"
            } else {
                item.isBook = false
                item.bookTitle = nil
                item.bookAuthor = nil
                item.name = name
            }
            
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
            // Create new item
            let newItem: Item
            if isBook {
                newItem = Item(title: bookTitle, author: bookAuthor, location: location)
            } else {
                newItem = Item(name: name, location: location)
            }
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
    
    private func checkForBookPattern(in text: String) {
        // Only check if we're creating a new item (not editing)
        guard item == nil else { return }
        
        let lowercased = text.lowercased()
        if let byRange = lowercased.range(of: " by ") {
            let titleEndIndex = text.index(text.startIndex, offsetBy: text.distance(from: text.startIndex, to: byRange.lowerBound))
            let authorStartIndex = text.index(text.startIndex, offsetBy: text.distance(from: text.startIndex, to: byRange.upperBound))
            
            let title = String(text[..<titleEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let author = String(text[authorStartIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !title.isEmpty && !author.isEmpty {
                suggestedTitle = title
                suggestedAuthor = author
                showBookSuggestion = true
            }
        }
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

// MARK: - Bulk Duplicate List View

enum BulkDuplicateDecision {
    case keep       // Add anyway
    case skip       // Don't add
    case editedName(String)  // Add with a different name
}

struct BulkDuplicateGroup: Identifiable {
    let id = UUID()
    let newItemName: String
    let matches: [DuplicateMatch]
    var decision: BulkDuplicateDecision = .keep
}

struct BulkDuplicateListView: View {
    @State var groups: [BulkDuplicateGroup]
    let onCancel: () -> Void   // "Add All Anyway" - adds everything, duplicates included
    let onConfirm: ([BulkDuplicateGroup]) -> Void  // Confirm with per-item decisions

    @State private var editingGroupIndex: Int?
    @State private var editingName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Some items you're adding look similar to existing items. Review each one below, or tap \"Add All\" to add everything.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    Section {
                        // New item name
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                                Text(displayName(for: group))
                                    .fontWeight(.semibold)
                            }

                            // Decision badge
                            decisionBadge(for: group.decision)
                        }

                        // Existing matches
                        ForEach(group.matches) { match in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(match.name)
                                        .font(.subheadline)
                                    Text(match.locationPath)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(Int(match.score * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }

                        // Action buttons
                        HStack(spacing: 12) {
                            Button {
                                groups[index].decision = .keep
                            } label: {
                                Label("Add", systemImage: "plus.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .tint(.green)

                            Button {
                                groups[index].decision = .skip
                            } label: {
                                Label("Skip", systemImage: "xmark.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)

                            Button {
                                editingGroupIndex = index
                                editingName = group.newItemName
                            } label: {
                                Label("Edit", systemImage: "pencil.circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        }
                    } header: {
                        Text("Item \(index + 1) of \(groups.count)")
                    }
                }
            }
            .navigationTitle("Review Duplicates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Add All") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") { onConfirm(groups) }
                }
            }
            .alert("Edit Item Name", isPresented: Binding(
                get: { editingGroupIndex != nil },
                set: { if !$0 { editingGroupIndex = nil } }
            )) {
                TextField("Item Name", text: $editingName)
                Button("Save") {
                    if let index = editingGroupIndex, !editingName.isEmpty {
                        groups[index].decision = .editedName(editingName)
                        editingGroupIndex = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    editingGroupIndex = nil
                }
            }
        }
    }

    private func displayName(for group: BulkDuplicateGroup) -> String {
        switch group.decision {
        case .editedName(let name): return name
        default: return group.newItemName
        }
    }

    @ViewBuilder
    private func decisionBadge(for decision: BulkDuplicateDecision) -> some View {
        switch decision {
        case .keep:
            Label("Will add", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
        case .skip:
            Label("Will skip", systemImage: "xmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.red)
        case .editedName(let name):
            Label("Will add as: \(name)", systemImage: "pencil.circle.fill")
                .font(.caption2)
                .foregroundColor(.blue)
        }
    }
}
