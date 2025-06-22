import SwiftUI
import SwiftData

struct LocationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var location: Location

    @State private var isAddingLocation = false
    @State private var isAddingItem     = false
    @State private var isEditingLocation = false

    // Movement state
    private enum MoveTarget { case location(Location), item(Item) }
    @State private var moveTarget: MoveTarget?
    @State private var showMoveSheet = false
    @State private var showDepthAlert = false

    var body: some View {
        List {
            // MARK: Sub-Locations
            Section("Sub-Locations") {
                if location.children.isEmpty {
                    Text("No sub-locations yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(location.children.sorted { $0.name < $1.name }) { child in
                        NavigationLink(value: child) { Text(child.name) }
                            .swipeActions {
                                Button("Move") {
                                    moveTarget = .location(child)
                                    showMoveSheet = true
                                }
                            }
                    }
                    .onDelete(perform: deleteChildren)
                }
            }

            // MARK: Items
            Section("Items in this Location") {
                if location.items.isEmpty {
                    Text("No items stored here yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(location.items.sorted { $0.name < $1.name }) { item in
                        Text(item.name)
                            .swipeActions {
                                Button("Move") {
                                    moveTarget = .item(item)
                                    showMoveSheet = true
                                }
                            }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
        }
        .navigationTitle(location.name)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Edit", systemImage: "pencil") { isEditingLocation = true }
                Menu {
                    Button("Add Sub-Location",
                           systemImage: "plus.rectangle.on.folder",
                           action: { isAddingLocation = true })
                        .disabled(location.depth >= 15)          // depth cap
                    Button("Add Item",
                           systemImage: "plus.square.on.square",
                           action: { isAddingItem = true })
                } label: { Label("Add", systemImage: "plus") }
            }
        }
        // Sheets
        .sheet(isPresented: $isAddingLocation) {
            LocationEditView(location: nil, parentLocation: location)
        }
        .sheet(isPresented: $isAddingItem) {
            ItemEditView(item: nil, location: location)
        }
        .sheet(isPresented: $isEditingLocation) {
            LocationEditView(location: location, parentLocation: location.parent)
        }
        // Move-to picker
        .sheet(isPresented: $showMoveSheet) {
            if let moveTarget = moveTarget {
                MoveDestinationPicker(
                    forbiddenIDs: forbiddenSet(for: moveTarget)) { destination in
                        performMove(to: destination, target: moveTarget)
                    }
            }
        }
        // Depth alert
        .alert("Hierarchy too deep",
               isPresented: $showDepthAlert,
               actions: { Button("OK", role: .cancel) { } },
               message: { Text("Moving here would exceed the 15-level limit.") })
        .navigationDestination(for: Location.self) { LocationDetailView(location: $0) }
    }

    // MARK: - Move helpers
    private func forbiddenSet(for target: MoveTarget) -> Set<UUID> {
        switch target {
        case .item:
            return []                       // items can go anywhere
        case .location(let loc):
            return loc.collectIDs()         // cannot move into self/descendants
        }
    }

    private func performMove(to destination: Location, target: MoveTarget) {
        switch target {
        case .item(let item):
            item.location = destination

        case .location(let loc):
            let extraDepth = loc.deepestSubtreeDistance()
            if destination.depth + 1 + extraDepth > 15 {
                showDepthAlert = true
                return
            }
            loc.parent = destination
        }
    }

    // MARK: - Delete helpers
    private func deleteChildren(offsets: IndexSet) {
        let sorted = location.children.sorted { $0.name < $1.name }
        withAnimation { offsets.forEach { modelContext.delete(sorted[$0]) } }
    }

    private func deleteItems(offsets: IndexSet) {
        let sorted = location.items.sorted { $0.name < $1.name }
        withAnimation { offsets.forEach { modelContext.delete(sorted[$0]) } }
    }
}
