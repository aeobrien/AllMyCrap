import SwiftUI
import SwiftData

struct TagPicker: View {
    @Binding var selectedTags: [Tag]
    @Environment(\.modelContext) private var modelContext
    @Query private var allTags: [Tag]
    @State private var showingNewTag = false
    @State private var newTagName = ""
    @State private var newTagColor = Color.blue
    
    var body: some View {
        NavigationStack {
            List {
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
                }
                
                Button(action: { showingNewTag = true }) {
                    Label("Create New Tag", systemImage: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .navigationTitle("Select Tags")
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }
}