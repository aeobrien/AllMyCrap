import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss

    // Grab every item once; tiny personal inventories won’t hurt memory,
    // and it keeps the query logic simple for now.
    @Query(sort: \Item.name) private var allItems: [Item]

    @State private var searchText = ""

    // Filter in memory – fine for thousands of rows.
    private var filteredItems: [Item] {
        guard !searchText.isEmpty else { return allItems }
        return allItems.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if allItems.isEmpty {
                    ContentUnavailableView("No items yet",
                                           systemImage: "square.stack.3d.up.slash",
                                           description: Text("Add items to your locations to see them here."))
                } else if !searchText.isEmpty && filteredItems.isEmpty {
                    ContentUnavailableView("No matches",
                                           systemImage: "magnifyingglass",
                                           description: Text("Try a different name."))
                } else {
                    ForEach(filteredItems) { item in
                        if let loc = item.location {
                            NavigationLink(value: loc) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                    Text(path(for: loc))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Text(item.name)
                        }
                    }
                }
            }
            .navigationDestination(for: Location.self) { LocationDetailView(location: $0) }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Item name")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    // Builds “Room › Cupboard › Shelf” style paths.
    private func path(for location: Location) -> String {
        var parts: [String] = [location.name]
        var current = location.parent
        while let next = current {
            parts.append(next.name)
            current = next.parent
        }
        return parts.reversed().joined(separator: " › ")
    }
}
