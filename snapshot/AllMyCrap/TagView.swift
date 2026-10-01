import SwiftUI
import SwiftData

struct TagView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tags: [Tag]
    @State private var showingAddTag = false
    @State private var newTagName = ""
    @State private var newTagColor = Color.blue
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(tags.sorted { $0.name < $1.name }) { tag in
                    HStack {
                        Circle()
                            .fill(Color(hex: tag.color) ?? .blue)
                            .frame(width: 20, height: 20)
                        Text(tag.name)
                        Spacer()
                        Text("\(tag.items.count)")
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            modelContext.delete(tag)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Tags")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Tag", systemImage: "plus") {
                        showingAddTag = true
                    }
                }
            }
            .sheet(isPresented: $showingAddTag) {
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
                                showingAddTag = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                let tag = Tag(name: newTagName, color: newTagColor.toHex())
                                modelContext.insert(tag)
                                newTagName = ""
                                showingAddTag = false
                            }
                            .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
    }
}

// Color extensions
extension Color {
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        
        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}