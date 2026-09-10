import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Item> { $0.isArchived == true }, sort: \Item.dateAdded, order: .reverse) private var archivedItems: [Item]

    @State private var searchText = ""
    @State private var filterPlan: ItemPlan?
    @State private var showingDeleteConfirmation = false
    @State private var itemToDelete: Item?

    private var filteredItems: [Item] {
        var items = archivedItems

        if let plan = filterPlan {
            items = items.filter { $0.archivedPlan == plan }
        }

        if !searchText.isEmpty {
            items = items.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort by archivedDate descending (most recent first)
        return items.sorted { ($0.archivedDate ?? .distantPast) > ($1.archivedDate ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            List {
                if archivedItems.isEmpty {
                    ContentUnavailableView(
                        "No Archived Items",
                        systemImage: "archivebox",
                        description: Text("Items you archive through Action Mode will appear here.")
                    )
                } else if filteredItems.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    planFilterRow

                    ForEach(filteredItems) { item in
                        archivedItemRow(item)
                            .swipeActions(edge: .leading) {
                                Button("Restore") {
                                    restoreItem(item)
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    itemToDelete = item
                                    showingDeleteConfirmation = true
                                }
                            }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search archived items")
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Permanently?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let item = itemToDelete {
                        modelContext.delete(item)
                        do {
                            try modelContext.save()
                        } catch {
                            print("Failed to delete item: \(error)")
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This item will be permanently deleted. This cannot be undone.")
            }
        }
    }

    // MARK: - Views

    @ViewBuilder
    private var planFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", isActive: filterPlan == nil) {
                    filterPlan = nil
                }
                ForEach(ItemPlan.allCases.filter { $0 != .keep }, id: \.self) { plan in
                    let count = archivedItems.filter { $0.archivedPlan == plan }.count
                    if count > 0 {
                        filterChip(label: "\(plan.rawValue) (\(count))", isActive: filterPlan == plan) {
                            filterPlan = plan
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func filterChip(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isActive ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isActive ? .white : .primary)
                .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func archivedItemRow(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.displayName)
                .font(.body)

            HStack(spacing: 12) {
                if let plan = item.archivedPlan {
                    HStack(spacing: 4) {
                        planIcon(for: plan)
                        Text(plan.rawValue)
                    }
                    .font(.caption)
                    .foregroundColor(planColor(for: plan))
                }

                if let date = item.archivedDate {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let location = item.location {
                Text(locationPath(for: location))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func restoreItem(_ item: Item) {
        item.isArchived = false
        item.archivedDate = nil
        // Restore the plan that was active when archived
        if let archivedPlan = item.archivedPlan {
            item.plan = archivedPlan
        }
        item.archivedPlan = nil
        do {
            try modelContext.save()
        } catch {
            print("Failed to restore item: \(error)")
        }
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

    @ViewBuilder
    private func planIcon(for plan: ItemPlan) -> some View {
        switch plan {
        case .keep: Image(systemName: "checkmark")
        case .throwAway: Text("✕")
        case .sell: Text("£")
        case .charity: Image(systemName: "heart.fill")
        case .move: Image(systemName: "house")
        case .fix: Image(systemName: "wrench")
        }
    }

    private func planColor(for plan: ItemPlan) -> Color {
        switch plan {
        case .keep: return .green
        case .throwAway: return .red
        case .sell: return .blue
        case .charity: return .yellow
        case .move: return .purple
        case .fix: return .teal
        }
    }
}
