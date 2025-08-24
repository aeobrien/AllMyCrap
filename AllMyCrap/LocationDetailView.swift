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

    // MARK: - Move state
    private enum MoveTarget { case location(Location), item(Item) }
    @State private var moveTarget: MoveTarget?
    @State private var showMoveSheet = false
    @State private var showDepthAlert = false
    @State private var selectedDestination = ""
    
    // MARK: - Batch selection state
    @State private var isInSelectionMode = false
    @State private var selectedItems: Set<Item> = []
    @State private var showBatchTagPicker = false
    @State private var selectedBatchTags: [Tag] = []
    @State private var showBatchMoveSheet = false
    @State private var batchMoveDestination = ""
    
    // MARK: - View options state
    @State private var showRecursiveItems = false
    @State private var filterTag: Tag? = nil
    @State private var filterPlan: ItemPlan? = nil
    @State private var showingTinderMode = false
    
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
        mainListView
            .navigationTitle(location.name)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingTinderMode = true }) {
                        Image(systemName: "rectangle.stack.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.orange)
                    }
                    
                    Button("Edit", systemImage: "pencil") { 
                        isEditingLocation = true 
                    }
                }
            }
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
            .sheet(isPresented: $isEditingLocation) {
                LocationEditView(location: location, parentLocation: location.parent)
            }
            .sheet(item: $itemToEdit) { selected in
                if let loc = selected.location {
                    ItemEditView(item: selected, location: loc)
                }
            }
            .sheet(item: $locationToEdit) { toEdit in
                LocationEditView(location: toEdit, parentLocation: toEdit.parent)
            }
            .sheet(isPresented: $showMoveSheet) {
                moveDestinationSheet
            }
            .alert("Hierarchy too deep",
                   isPresented: $showDepthAlert,
                   actions: { Button("OK", role: .cancel) {} },
                   message:  { Text("Moving here would exceed the 15‑level limit.") })
            .sheet(item: $itemForTags) { item in
                itemTagPickerSheet(for: item)
            }
            .fullScreenCover(isPresented: $showingTinderMode) {
                TinderModeView(location: location)
            }
            .sheet(isPresented: $showBatchTagPicker) {
                batchTagPickerSheet
            }
            .sheet(isPresented: $showBatchMoveSheet) {
                batchMoveSheet
            }
    }
    
    @ViewBuilder
    private var mainListView: some View {
        List {
            subLocationsSection
            itemsSection
        } 
    }
    
    @ViewBuilder
    private var moveDestinationSheet: some View {
        if let moveTarget {
            let item: Item? = {
                switch moveTarget {
                case .item(let item):
                    return item
                case .location:
                    return nil
                }
            }()
            
            MoveDestinationPicker(
                selectedDestination: $selectedDestination,
                item: item,
                onConfirm: { destination in
                    if let location = findLocationByPath(destination) {
                        performMove(to: location, target: moveTarget)
                        showMoveSheet = false
                        selectedDestination = ""
                    }
                }
            )
        }
    }
    
    @ViewBuilder
    private func itemTagPickerSheet(for item: Item) -> some View {
        NavigationStack {
            TagPicker(selectedTags: $selectedTagsForItem)
                .navigationTitle("Tags for \(item.name)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            for tag in item.tags {
                                tag.items.removeAll { $0.id == item.id }
                            }
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
    
    @ViewBuilder
    private var batchTagPickerSheet: some View {
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
    
    @ViewBuilder
    private var batchMoveSheet: some View {
        MoveDestinationPicker(
            selectedDestination: $batchMoveDestination,
            item: nil,
            onConfirm: { destination in
                if let location = findLocationByPath(destination) {
                    batchMove(to: location)
                    showBatchMoveSheet = false
                    batchMoveDestination = ""
                }
            }
        )
    }

    // MARK: - Move helpers
    private func findLocationByPath(_ path: String) -> Location? {
        // Try to find a location matching the path
        let allLocations = try? modelContext.fetch(FetchDescriptor<Location>())
        guard let locations = allLocations else { return nil }
        
        for location in locations {
            if fullPath(for: location) == path {
                return location
            }
        }
        return nil
    }
    
    private func fullPath(for location: Location) -> String {
        var parts = [location.name]
        var current = location.parent
        while let next = current {
            parts.append(next.name)
            current = next.parent
        }
        return parts.reversed().joined(separator: " › ")
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
        case .move:
            return .purple
        case .fix:
            return .teal
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var subLocationsSection: some View {
        Section("Sub‑Locations") {
            ForEach(location.children.sorted { $0.name < $1.name }) { child in
                subLocationRow(for: child)
            }
            .onDelete(perform: deleteChildren)
            
            addSubLocationButtons
        }
    }
    
    @ViewBuilder
    private func subLocationRow(for child: Location) -> some View {
        NavigationLink(value: child) {
            HStack(spacing: 0) {
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
    
    @ViewBuilder
    private var addSubLocationButtons: some View {
        Group {
            Button(action: { isAddingLocation = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    Text("Add Sub-Location")
                        .foregroundColor(.blue)
                }
            }
            .disabled(location.depth >= 15)
            
            Button(action: { isAddingMultipleLocations = true }) {
                HStack {
                    Image(systemName: "plus.rectangle.on.folder.fill")
                        .foregroundColor(.blue)
                    Text("Add Multiple Sub-Locations")
                        .foregroundColor(.blue)
                }
            }
            .disabled(location.depth >= 15)
        }
    }
    
    @ViewBuilder
    private var itemsSection: some View {
        Section("Items in this Location") {
            filterRow
            selectionControls
            itemsList
            addItemButtons
        }
    }
    
    @ViewBuilder
    private var filterRow: some View {
        HStack(spacing: 12) {
            locationFilterMenu
            planFilterMenu
            tagFilterMenu
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var locationFilterMenu: some View {
        Menu {
            Button(showRecursiveItems ? "✓ Include Sublocations" : "Include Sublocations") {
                showRecursiveItems = true
            }
            Button(!showRecursiveItems ? "✓ This Location Only" : "This Location Only") {
                showRecursiveItems = false
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "location")
                    .font(.caption)
                Text(showRecursiveItems ? "Include Sublocations" : "This Location Only")
                    .font(.caption)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))
            .cornerRadius(6)
        }
    }
    
    @ViewBuilder
    private var planFilterMenu: some View {
        Menu {
            Button("No Filter") {
                filterPlan = nil
            }
            Divider()
            ForEach(ItemPlan.allCases, id: \.self) { plan in
                Button(filterPlan == plan ? "✓ \(plan.rawValue)" : plan.rawValue) {
                    filterPlan = plan
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .font(.caption)
                Text(filterPlan?.rawValue ?? "Plan")
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(filterPlan != nil ? .blue : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(filterPlan != nil ? .blue.opacity(0.1) : Color(.systemGray5)))
            .cornerRadius(6)
        }
    }
    
    @ViewBuilder
    private var tagFilterMenu: some View {
        Menu {
            Button("No Filter") {
                filterTag = nil
            }
            Divider()
            ForEach(allTags.sorted { $0.name < $1.name }) { tag in
                Button(filterTag == tag ? "✓ \(tag.name)" : tag.name) {
                    filterTag = tag
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "tag")
                    .font(.caption)
                Text(filterTag?.name ?? "Tag")
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundColor(filterTag != nil ? .blue : .primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(filterTag != nil ? .blue.opacity(0.1) : Color(.systemGray5)))
            .cornerRadius(6)
        }
    }
    
    @ViewBuilder
    private var selectionControls: some View {
        VStack(spacing: 8) {
            if isInSelectionMode {
                selectionModeHeader
                batchActionButtons
            } else {
                HStack {
                    Button("Select") {
                        isInSelectionMode = true
                    }
                    .fontWeight(.medium)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    @ViewBuilder
    private var selectionModeHeader: some View {
        HStack {
            Button("Done") {
                exitSelectionMode()
            }
            .fontWeight(.semibold)
            
            Spacer()
            
            Text("\(selectedItems.count) selected")
                .foregroundColor(.secondary)
            
            Spacer()
            
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
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var batchActionButtons: some View {
        HStack(spacing: 16) {
            Button {
                selectedBatchTags = []
                showBatchTagPicker = true
            } label: {
                Image(systemName: "tag.fill")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .disabled(selectedItems.isEmpty)
            
            Menu {
                Button("Keep") { batchApplyPlan(.keep) }
                Button("Throw Away") { batchApplyPlan(.throwAway) }
                Button("Sell") { batchApplyPlan(.sell) }
                Button("Charity") { batchApplyPlan(.charity) }
                Button("Move") { batchApplyPlan(.move) }
                Button("Fix") { batchApplyPlan(.fix) }
                Divider()
                Button("Clear Plan") { batchClearPlan() }
            } label: {
                Image(systemName: "checklist")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .disabled(selectedItems.isEmpty)
            
            Button {
                showBatchMoveSheet = true
            } label: {
                Image(systemName: "folder.fill")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .disabled(selectedItems.isEmpty)
            
            Spacer()
            
            Button(role: .destructive) {
                batchDelete()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(selectedItems.isEmpty)
        }
    }
    
    @ViewBuilder
    private var itemsList: some View {
        ForEach(itemsToDisplay) { item in
            itemRow(for: item)
        }
        .onDelete(perform: deleteItems)
    }
    
    @ViewBuilder
    private func itemRow(for item: Item) -> some View {
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
            .contentShape(Rectangle())
            .onTapGesture { 
                if !isInSelectionMode {
                    itemToEdit = item
                }
            }
            
            Spacer()
            
            if let plan = item.plan {
                planIcon(for: plan)
                    .foregroundColor(planColor(for: plan))
                    .padding(.horizontal, 4)
            }
            
            tagButton(for: item)
        }
        .contentShape(Rectangle())
        .contextMenu {
            contextMenuItems(for: item)
        }
        .swipeActions(allowsFullSwipe: false) {
            swipeActionItems(for: item)
        }
    }
    
    @ViewBuilder
    private func tagButton(for item: Item) -> some View {
        if !item.tags.isEmpty {
            Menu {
                ForEach(item.tags) { tag in
                    Label {
                        Text(tag.name)
                    } icon: {
                        Circle()
                            .fill(Color(hex: tag.color) ?? .blue)
                            .frame(width: 10, height: 10)
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    ForEach(item.tags.prefix(3)) { tag in
                        Circle()
                            .fill(Color(hex: tag.color) ?? .blue)
                            .frame(width: 8, height: 8)
                    }
                    if item.tags.count > 3 {
                        Text("+\(item.tags.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .disabled(isInSelectionMode)
        }
    }
    
    @ViewBuilder
    private func contextMenuItems(for item: Item) -> some View {
        Group {
            Button {
                itemToEdit = item
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            Button {
                moveTarget = .item(item)
                showMoveSheet = true
            } label: {
                Label("Move", systemImage: "folder")
            }
            
            Button {
                itemForTags = item
                selectedTagsForItem = item.tags
            } label: {
                Label("Edit Tags", systemImage: "tag")
            }
            
            Divider()
            
            Menu {
                Button("Keep") { assignPlan(.keep, to: item) }
                Button("Throw Away") { assignPlan(.throwAway, to: item) }
                Button("Sell") { assignPlan(.sell, to: item) }
                Button("Charity") { assignPlan(.charity, to: item) }
                Button("Move") { assignPlan(.move, to: item) }
                Button("Fix") { assignPlan(.fix, to: item) }
                Divider()
                Button("Clear Plan") { item.plan = nil }
            } label: {
                Label("Set Plan", systemImage: "checklist")
            }
            
            Divider()
            
            Button(role: .destructive) {
                deleteItem(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    @ViewBuilder
    private func swipeActionItems(for item: Item) -> some View {
        Button("Tags") {
            itemForTags = item
            selectedTagsForItem = item.tags
        }
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
    
    @ViewBuilder
    private var addItemButtons: some View {
        Group {
            Button(action: { isAddingItem = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                    Text("Add Item")
                        .foregroundColor(.green)
                }
            }
            
            Button(action: { isAddingMultipleItems = true }) {
                HStack {
                    Image(systemName: "plus.rectangle.on.rectangle.fill")
                        .foregroundColor(.green)
                    Text("Add Multiple Items")
                        .foregroundColor(.green)
                }
            }
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
