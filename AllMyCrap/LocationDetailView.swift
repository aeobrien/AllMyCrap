import SwiftUI
import SwiftData

/// Shows the contents of a single location (room, cupboard, shelf …) and lets the user
/// add / edit / move or delete both the items **and** the sub‑locations stored here.
struct LocationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var location: Location
    
    // Query to observe changes to children and items
    @Query private var allLocations: [Location]
    @Query private var allItems: [Item]
    
    private var currentChildren: [Location] {
        allLocations.filter { $0.parent?.id == location.id }
    }
    
    private var currentItems: [Item] {
        allItems.filter { $0.location?.id == location.id }
    }

    // MARK: - Creation state
    @State private var isAddingLocation   = false
    @State private var isAddingItem       = false
    @State private var isAddingMultipleItems = false
    @State private var isAddingMultipleLocations = false
    @State private var isEditingLocation  = false   // rename the **current** location

    // MARK: - Edit state (new)
    @State private var itemToEdit: Item?           // edit an existing item
    @State private var locationToEdit: Location?   // edit a child location
    @State private var itemForTags: Item?         // item to add tags to
    @State private var selectedTagsForItem: [Tag] = []

    // MARK: - Move state (unchanged)
    private enum MoveTarget { case location(Location), item(Item) }
    @State private var moveTarget: MoveTarget?
    @State private var showMoveSheet = false
    @State private var showDepthAlert = false

    var body: some View {
        List {
            // ───────── Sub‑locations ─────────
            Section("Sub‑Locations") {
                ForEach(currentChildren.sorted { $0.name < $1.name }) { child in
                    NavigationLink(value: child) {
                        HStack(spacing: 0) {
                            // Review indicator
                            Rectangle()
                                .fill(child.isReviewed ? Color.green : Color.clear)
                                .frame(width: 3)
                                .padding(.trailing, 8)
                            
                            Text(child.name)
                            Spacer()
                        }
                    }
                    .contextMenu {
                        Button(action: {
                            toggleReview(for: child)
                        }) {
                            Label(child.isReviewed ? "Mark as Unreviewed" : "Mark as Reviewed",
                                  systemImage: child.isReviewed ? "checkmark.circle.badge.xmark" : "checkmark.circle")
                        }
                        
                        Button(action: {
                            locationToEdit = child
                        }) {
                            Label("Edit Location", systemImage: "pencil")
                        }
                    }
                    // Extra swipe actions for move / edit / delete
                    .swipeActions(allowsFullSwipe: false) {
                        Button("Move") {
                            moveTarget = .location(child)
                            showMoveSheet = true
                        }
                        Button("Edit") {
                            locationToEdit = child
                        }
                        Button(role: .destructive) {
                            deleteChild(child)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                // Fallback editing‑mode delete (kept for macOS / iPadOS list editing)
                .onDelete(perform: deleteChildren)
                
                // Add sub-location button
                Button(action: { isAddingLocation = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Add Sub-Location")
                            .foregroundColor(.blue)
                    }
                }
                .disabled(location.depth >= 15)
            }

            // ───────── Items ─────────
            Section("Items in this Location") {
                ForEach(currentItems.sorted { $0.name < $1.name }) { item in
                    HStack {
                        Text(item.name)
                            // Tapping the row = rename the item
                            .contentShape(Rectangle())
                            .onTapGesture { itemToEdit = item }
                        
                        Spacer()
                        
                        // Plan indicator
                        if let plan = item.plan {
                            planIcon(for: plan)
                                .foregroundColor(planColor(for: plan))
                                .padding(.horizontal, 4)
                        }
                        
                        // Tag button
                        Button(action: {
                            itemForTags = item
                            selectedTagsForItem = item.tags
                        }) {
                            Image(systemName: item.tags.isEmpty ? "tag" : "tag.fill")
                                .foregroundColor(item.tags.isEmpty ? .gray : .blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    // Swipe left for move / edit / delete
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Move") {
                            moveTarget = .item(item)
                            showMoveSheet = true
                        }
                        Button("Edit") {
                            itemToEdit = item
                        }
                        Button(role: .destructive) {
                            deleteItem(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    // Swipe right for plan assignment
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            assignPlan(.keep, to: item)
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .tint(.green)
                        
                        Button {
                            assignPlan(.throwAway, to: item)
                        } label: {
                            Text("✕")
                        }
                        .tint(.red)
                        
                        Button {
                            assignPlan(.sell, to: item)
                        } label: {
                            Text("£")
                        }
                        .tint(.blue)
                        
                        Button {
                            assignPlan(.charity, to: item)
                        } label: {
                            Image(systemName: "heart.fill")
                        }
                        .tint(.yellow)
                        
                        Button {
                            assignPlan(.move, to: item)
                        } label: {
                            Image(systemName: "house")
                        }
                        .tint(.purple)
                    }
                }
                .onDelete(perform: deleteItems)
                
                // Add item button
                Button(action: { isAddingItem = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Add Item")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle(location.name)
        // ───────── Toolbar ─────────
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Edit", systemImage: "pencil") { isEditingLocation = true }
                Menu {
                    Button("Add Sub‑Location",
                           systemImage: "plus.rectangle.on.folder") {
                        isAddingLocation = true
                    }
                    .disabled(location.depth >= 15)   // keep depth cap
                    Button("Add Multiple Sub-Locations",
                           systemImage: "plus.rectangle.on.folder.fill") {
                        isAddingMultipleLocations = true
                    }
                    .disabled(location.depth >= 15)   // keep depth cap
                    Divider()
                    Button("Add Item",
                           systemImage: "plus.square.on.square") {
                        isAddingItem = true
                    }
                    Button("Add Multiple Items",
                           systemImage: "square.stack") {
                        isAddingMultipleItems = true
                    }
                } label: { Label("Add", systemImage: "plus") }
            }
        }
        // ───────── Creation sheets ─────────
        .sheet(isPresented: $isAddingLocation) {
            LocationEditView(location: nil, parentLocation: location)
        }
        .sheet(isPresented: $isAddingItem) {
            ItemEditView(item: nil, location: location)
        }
        .sheet(isPresented: $isAddingMultipleItems) {
            BulkItemAddView(location: location)
        }
        .sheet(isPresented: $isAddingMultipleLocations) {
            BulkLocationAddView(parentLocation: location)
        }
        // ───────── Edit sheets ─────────
        .sheet(isPresented: $isEditingLocation) {
            LocationEditView(location: location, parentLocation: location.parent)
        }
        .sheet(item: $itemToEdit) { selected in
            // `ItemEditView` needs the current parent location as well
            if let loc = selected.location {
                ItemEditView(item: selected, location: loc)
            }
        }
        .sheet(item: $locationToEdit) { toEdit in
            LocationEditView(location: toEdit, parentLocation: toEdit.parent)
        }
        // ───────── Move picker ─────────
        .sheet(isPresented: $showMoveSheet) {
            if let moveTarget {
                MoveDestinationPicker(forbiddenIDs: forbiddenSet(for: moveTarget)) { destination in
                    performMove(to: destination, target: moveTarget)
                }
            }
        }
        // ───────── Depth alert ─────────
        .alert("Hierarchy too deep",
               isPresented: $showDepthAlert,
               actions: { Button("OK", role: .cancel) {} },
               message:  { Text("Moving here would exceed the 15‑level limit.") })
        // Tag picker sheet
        .sheet(item: $itemForTags) { item in
            NavigationStack {
                TagPicker(selectedTags: $selectedTagsForItem)
                    .navigationTitle("Tags for \(item.name)")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                // Remove item from old tags
                                for tag in item.tags {
                                    tag.items.removeAll { $0.id == item.id }
                                }
                                // Set new tags and update bidirectional relationship
                                item.tags = selectedTagsForItem
                                for tag in selectedTagsForItem {
                                    if !tag.items.contains(where: { $0.id == item.id }) {
                                        tag.items.append(item)
                                    }
                                }
                                do {
                                    try modelContext.save()
                                } catch {
                                    print("Failed to save tags: \(error)")
                                }
                                itemForTags = nil
                            }
                        }
                    }
            }
        }
        // Deep‑link navigation
        .navigationDestination(for: Location.self) { LocationDetailView(location: $0) }
    }

    // MARK: - Move helpers (unchanged)
    private func forbiddenSet(for target: MoveTarget) -> Set<UUID> {
        switch target {
        case .item:                    return []            // items can go anywhere
        case .location(let loc):       return loc.collectIDs() // block self/descendants
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

    // MARK: - Delete helpers (new convenience variants)
    private func deleteChild(_ child: Location) {
        withAnimation { modelContext.delete(child) }
    }

    private func deleteItem(_ item: Item) {
        withAnimation { modelContext.delete(item) }
    }

    // Existing offset‑based deletes kept for iPadOS/macOS edit‑mode support
    private func deleteChildren(offsets: IndexSet) {
        let sorted = currentChildren.sorted { $0.name < $1.name }
        withAnimation { offsets.forEach { modelContext.delete(sorted[$0]) } }
    }

    private func deleteItems(offsets: IndexSet) {
        let sorted = currentItems.sorted { $0.name < $1.name }
        withAnimation { offsets.forEach { modelContext.delete(sorted[$0]) } }
    }
    
    // MARK: - Review helpers
    private func toggleReview(for location: Location) {
        withAnimation(.easeInOut(duration: 0.3)) {
            location.isReviewed.toggle()
            location.lastReviewedDate = location.isReviewed ? Date() : nil
            
            // Add history entry
            let historyEntry = ReviewHistory(
                action: location.isReviewed ? .markedReviewed : .markedUnreviewed,
                isAutomatic: false,
                location: location
            )
            modelContext.insert(historyEntry)
            
            do {
                try modelContext.save()
            } catch {
                print("Failed to save review status: \(error)")
            }
        }
    }
    
    // MARK: - Plan helpers
    private func assignPlan(_ plan: ItemPlan, to item: Item) {
        withAnimation {
            item.plan = plan
            do {
                try modelContext.save()
            } catch {
                print("Failed to save plan: \(error)")
            }
        }
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
        case .move:
            return .purple
        }
    }
}
