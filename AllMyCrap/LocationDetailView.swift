import SwiftUI
import SwiftData

/// Shows the contents of a single location (room, cupboard, shelf …) and lets the user
/// add / edit / move or delete both the items **and** the sub‑locations stored here.
struct LocationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var location: Location
    @Query private var allTags: [Tag]

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
    
    // MARK: - Batch selection state
    @State private var isInSelectionMode = false
    @State private var selectedItems: Set<Item> = []
    @State private var showBatchActionSheet = false
    @State private var showBatchTagPicker = false
    @State private var selectedBatchTags: [Tag] = []
    
    // MARK: - View options state
    @State private var showRecursiveItems = false
    @State private var filterTag: Tag? = nil
    @State private var filterPlan: ItemPlan? = nil
    
    private var filterLabel: String {
        if let plan = filterPlan {
            return "Plan: \(plan.rawValue)"
        } else if let tag = filterTag {
            return "Tag: \(tag.name)"
        } else {
            return "Filter"
        }
    }
    
    // Computed property for items to display
    private var itemsToDisplay: [Item] {
        var items: [Item] = []
        
        if showRecursiveItems {
            // Include items from this location and all sub-locations recursively
            items = getAllItemsRecursively(from: location)
        } else {
            // Just items directly in this location
            items = location.items
        }
        
        // Apply filters
        if let tag = filterTag {
            items = items.filter { $0.tags.contains(tag) }
        }
        
        if let plan = filterPlan {
            items = items.filter { $0.plan == plan }
        }
        
        return items.sorted { $0.displayName < $1.displayName }
    }
    
    private func getAllItemsRecursively(from location: Location) -> [Item] {
        var allItems = location.items
        for child in location.children {
            allItems.append(contentsOf: getAllItemsRecursively(from: child))
        }
        return allItems
    }
    
    private func getRelativePath(for item: Item) -> String? {
        guard let itemLocation = item.location, itemLocation != location else {
            return nil
        }
        
        var path: [String] = []
        var current: Location? = itemLocation
        
        while let loc = current, loc != location {
            path.insert(loc.name, at: 0)
            current = loc.parent
        }
        
        return path.isEmpty ? nil : path.joined(separator: " > ")
    }

    var body: some View {
        List {
            // ───────── Sub‑locations ─────────
            Section("Sub‑Locations") {
                ForEach(location.children.sorted { $0.name < $1.name }) { child in
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
                    .disabled(isInSelectionMode)
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
                // View options
                VStack(spacing: 10) {
                    // Scope toggle
                    Picker("Scope", selection: $showRecursiveItems) {
                        Text("This Location Only").tag(false)
                        Text("Include Sub-locations").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // Filter options
                    HStack {
                        Menu {
                            Button("No Filter") {
                                filterTag = nil
                                filterPlan = nil
                            }
                            
                            Section("Filter by Plan") {
                                ForEach(ItemPlan.allCases, id: \.self) { plan in
                                    Button(plan.rawValue) {
                                        filterPlan = plan
                                        filterTag = nil
                                    }
                                }
                            }
                            
                            Section("Filter by Tag") {
                                ForEach(allTags.sorted { $0.name < $1.name }) { tag in
                                    Button(tag.name) {
                                        filterTag = tag
                                        filterPlan = nil
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(filterLabel)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        if filterTag != nil || filterPlan != nil {
                            Button("Clear") {
                                filterTag = nil
                                filterPlan = nil
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                ForEach(itemsToDisplay) { item in
                    let isSelected = selectedItems.contains(item)
                    
                    HStack {
                        if isInSelectionMode {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? .accentColor : .gray)
                                .onTapGesture {
                                    if isSelected {
                                        selectedItems.remove(item)
                                    } else {
                                        selectedItems.insert(item)
                                    }
                                }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.displayName)
                                .foregroundColor(.primary)
                            
                            if showRecursiveItems, let relativePath = getRelativePath(for: item) {
                                Text(relativePath)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        // Tapping the row = rename the item
                        .contentShape(Rectangle())
                        .onTapGesture { 
                            if !isInSelectionMode {
                                itemToEdit = item
                            }
                        }
                        
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
                if isInSelectionMode {
                    Menu {
                        Button("Select All") {
                            selectAll()
                        }
                        
                        if !selectedItems.isEmpty {
                            Button("Clear Selection") {
                                selectedItems.removeAll()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    
                    Button("Done") {
                        exitSelectionMode()
                    }
                    .fontWeight(.semibold)
                    
                    if !selectedItems.isEmpty {
                        Button("Actions") {
                            showBatchActionSheet = true
                        }
                    }
                } else {
                    Button("Select") {
                        isInSelectionMode = true
                    }
                    
                    Button("Edit", systemImage: "pencil") { isEditingLocation = true }
                }
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
        // Batch tag picker sheet
        .sheet(isPresented: $showBatchTagPicker) {
            NavigationStack {
                TagPicker(selectedTags: $selectedBatchTags)
                    .navigationTitle("Tags for \(selectedItems.count) items")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showBatchTagPicker = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Apply") {
                                batchApplyTags(selectedBatchTags)
                                showBatchTagPicker = false
                            }
                        }
                    }
            }
        }
        // Batch action sheet
        .confirmationDialog("Batch Actions", isPresented: $showBatchActionSheet) {
            Button("Apply Tags") {
                selectedBatchTags = []
                showBatchTagPicker = true
            }
            
            // Plan options
            Button("Set Plan: Keep") { batchApplyPlan(.keep) }
            Button("Set Plan: Throw Away") { batchApplyPlan(.throwAway) }
            Button("Set Plan: Sell") { batchApplyPlan(.sell) }
            Button("Set Plan: Charity") { batchApplyPlan(.charity) }
            Button("Set Plan: Move") { batchApplyPlan(.move) }
            Button("Clear Plan") { batchClearPlan() }
            
            Button("Move to Location") {
                showMoveSheet = true
            }
            
            Button("Delete", role: .destructive) {
                batchDelete()
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose an action for \(selectedItems.count) item\(selectedItems.count == 1 ? "" : "s")")
        }
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
        let sorted = location.children.sorted { $0.name < $1.name }
        withAnimation { offsets.forEach { modelContext.delete(sorted[$0]) } }
    }

    private func deleteItems(offsets: IndexSet) {
        let sorted = location.items.sorted { $0.name < $1.name }
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
    
    // MARK: - Batch Selection
    private func exitSelectionMode() {
        isInSelectionMode = false
        selectedItems.removeAll()
    }
    
    private func selectAll() {
        // Select all visible items
        for item in itemsToDisplay {
            selectedItems.insert(item)
        }
    }
    
    private func batchApplyTags(_ tags: [Tag]) {
        for item in selectedItems {
            item.tags = tags
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save batch tag changes: \(error)")
        }
        
        exitSelectionMode()
    }
    
    private func batchApplyPlan(_ plan: ItemPlan) {
        for item in selectedItems {
            item.plan = plan
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save batch plan changes: \(error)")
        }
        
        exitSelectionMode()
    }
    
    private func batchClearPlan() {
        for item in selectedItems {
            item.plan = nil
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to clear batch plans: \(error)")
        }
        
        exitSelectionMode()
    }
    
    private func batchMove(to destination: Location) {
        for item in selectedItems {
            item.location = destination
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save batch move: \(error)")
        }
        
        exitSelectionMode()
    }
    
    private func batchDelete() {
        for item in selectedItems {
            modelContext.delete(item)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save batch delete: \(error)")
        }
        
        exitSelectionMode()
    }
}
