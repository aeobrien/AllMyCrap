import SwiftUI
import SwiftData

struct BulkItemPreviewView: View {
    @Binding var parsedItems: [BulkItemAddView.ParsedItem]
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Query private var allTags: [Tag]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach($parsedItems) { $item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Item name", text: $item.name)
                                .font(.headline)
                            
                            // Show book indicator if detected
                            if item.name.contains(" by ") {
                                Image(systemName: "books.vertical.fill")
                                    .foregroundColor(.purple)
                                    .font(.caption)
                            }
                        }
                        
                        // Tags section
                        HStack {
                            Image(systemName: "tag")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            
                            if item.tags.isEmpty {
                                Text("No tags")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 4) {
                                        ForEach(item.tags, id: \.self) { tag in
                                            Text(tag)
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.2))
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Plan section
                        HStack {
                            Text("Plan:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let plan = item.plan {
                                HStack(spacing: 4) {
                                    planIcon(for: plan)
                                    Text(plan.rawValue)
                                }
                                .font(.caption)
                                .foregroundColor(planColor(for: plan))
                            } else {
                                Text("None")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Menu {
                                Button("None") { item.plan = nil }
                                ForEach(ItemPlan.allCases, id: \.self) { plan in
                                    Button(action: { item.plan = plan }) {
                                        HStack {
                                            planIcon(for: plan)
                                            Text(plan.rawValue)
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Review Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add All") {
                        onConfirm()
                    }
                    .disabled(parsedItems.isEmpty)
                }
            }
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        parsedItems.remove(atOffsets: offsets)
    }
    
    @ViewBuilder
    private func planIcon(for plan: ItemPlan) -> some View {
        switch plan {
        case .keep:
            Image(systemName: "checkmark")
        case .throwAway:
            Text("✕")
        case .sell:
            Text("£")
        case .charity:
            Image(systemName: "heart.fill")
        case .move:
            Image(systemName: "house")
        case .fix:
            Image(systemName: "wrench")
        }
    }
    
    private func planColor(for plan: ItemPlan) -> Color {
        switch plan {
        case .keep:
            return .green
        case .throwAway:
            return .red
        case .sell:
            return .blue
        case .charity:
            return .yellow
        case .fix:
            return .teal
        case .move:
            return .purple
        }
    }
}