import SwiftUI
import SwiftData

struct ActionModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Item> { $0.isArchived == false }) private var allItems: [Item]

    @State private var selectedPlan: ItemPlan?
    @State private var checkedItems: Set<UUID> = []
    @State private var showingConfirmation = false

    private var actionablePlans: [(plan: ItemPlan, count: Int)] {
        ItemPlan.allCases
            .filter { $0 != .keep }
            .map { plan in
                let count = allItems.filter { $0.plan == plan }.count
                return (plan: plan, count: count)
            }
            .filter { $0.count > 0 }
    }

    private var planItems: [Item] {
        guard let plan = selectedPlan else { return [] }
        return allItems.filter { $0.plan == plan }
    }

    private var itemsByLocation: [(path: String, items: [Item])] {
        let grouped = Dictionary(grouping: planItems) { item in
            locationPath(for: item.location)
        }
        return grouped.sorted { $0.key < $1.key }.map { (path: $0.key, items: $0.value.sorted { $0.displayName < $1.displayName }) }
    }

    var body: some View {
        NavigationStack {
            if selectedPlan == nil {
                planPickerView
            } else {
                checklistView
            }
        }
    }

    // MARK: - Plan Picker

    @ViewBuilder
    private var planPickerView: some View {
        List {
            if actionablePlans.isEmpty {
                ContentUnavailableView(
                    "No Action Items",
                    systemImage: "checkmark.circle",
                    description: Text("No items have actionable plans assigned. Use Tinder Mode to assign plans first.")
                )
            } else {
                Section {
                    Text("Select a plan to execute. Items with that plan will be shown as a checklist grouped by location.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section("Plans") {
                    ForEach(actionablePlans, id: \.plan) { entry in
                        Button {
                            selectedPlan = entry.plan
                            checkedItems.removeAll()
                        } label: {
                            HStack {
                                planIcon(for: entry.plan)
                                    .foregroundColor(planColor(for: entry.plan))
                                    .frame(width: 30)
                                Text(entry.plan.rawValue)
                                Spacer()
                                Text("\(entry.count) items")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
        }
        .navigationTitle("Action Mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: - Checklist

    @ViewBuilder
    private var checklistView: some View {
        List {
            ForEach(itemsByLocation, id: \.path) { group in
                Section(group.path) {
                    ForEach(group.items) { item in
                        HStack {
                            Image(systemName: checkedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(checkedItems.contains(item.id) ? .green : .gray)
                                .onTapGesture {
                                    if checkedItems.contains(item.id) {
                                        checkedItems.remove(item.id)
                                    } else {
                                        checkedItems.insert(item.id)
                                    }
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.displayName)
                                if !item.tags.isEmpty {
                                    Text(item.tags.map { $0.name }.joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if checkedItems.contains(item.id) {
                                checkedItems.remove(item.id)
                            } else {
                                checkedItems.insert(item.id)
                            }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                HStack {
                    Button("Select All") {
                        for item in planItems {
                            checkedItems.insert(item.id)
                        }
                    }
                    .font(.caption)
                    Spacer()
                    if !checkedItems.isEmpty {
                        Button("Clear") {
                            checkedItems.removeAll()
                        }
                        .font(.caption)
                    }
                }

                Button {
                    showingConfirmation = true
                } label: {
                    Text("Archive \(checkedItems.count) Item\(checkedItems.count == 1 ? "" : "s")")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(checkedItems.isEmpty)
            }
            .padding()
            .background(.regularMaterial)
        }
        .navigationTitle(selectedPlan?.rawValue ?? "Action Mode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    selectedPlan = nil
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .alert("Archive Items?", isPresented: $showingConfirmation) {
            Button("Archive", role: .destructive) {
                archiveCheckedItems()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will archive \(checkedItems.count) item(s). They will be hidden from all views but can be restored from the Archive.")
        }
    }

    // MARK: - Actions

    private func archiveCheckedItems() {
        let now = Date()
        for item in planItems where checkedItems.contains(item.id) {
            item.isArchived = true
            item.archivedDate = now
            item.archivedPlan = item.plan
            item.plan = nil
        }
        do {
            try modelContext.save()
        } catch {
            print("Failed to archive items: \(error)")
        }

        // If all items archived, go back to plan picker
        if planItems.isEmpty {
            selectedPlan = nil
        }
        checkedItems.removeAll()
    }

    // MARK: - Helpers

    private func locationPath(for location: Location?) -> String {
        guard let location else { return "Unknown Location" }
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
