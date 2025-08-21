import SwiftUI
import SwiftData

struct TagSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tags: [Tag]
    @State private var selectedTag: Tag?
    @State private var tagToEdit: Tag?
    @State private var editingTagName = ""
    @State private var showDeleteAlert = false
    @State private var tagToDelete: Tag?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(tags.sorted { $0.name < $1.name }) { tag in
                    NavigationLink(destination: TagItemsView(tag: tag)) {
                        HStack {
                            Circle()
                                .fill(Color(hex: tag.color) ?? .blue)
                                .frame(width: 20, height: 20)
                            Text(tag.name)
                            Spacer()
                            Text("\(tag.items.count) items")
                                .foregroundStyle(.secondary)
                                .font(.caption)
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
            }
            .navigationTitle("Browse by Tag")
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
}

struct TagItemsView: View {
    let tag: Tag
    
    var body: some View {
        List {
            ForEach(tag.items.sorted { $0.name < $1.name }) { item in
                NavigationLink(value: item.location) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.body)
                        
                        if let location = item.location {
                            Text(pathToLocation(location))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(tag.name)
        .navigationDestination(for: Location.self) { location in
            LocationDetailView(location: location)
        }
    }
    
    private func pathToLocation(_ location: Location) -> String {
        var path: [String] = []
        var current: Location? = location
        
        while let loc = current {
            path.insert(loc.name, at: 0)
            current = loc.parent
        }
        
        return path.joined(separator: " → ")
    }
}