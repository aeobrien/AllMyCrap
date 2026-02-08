import SwiftUI
import SwiftData

struct TinderModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let location: Location? // nil means all locations
    
    @Query private var allItems: [Item]
    @Query(sort: \Location.name) private var allLocations: [Location]

    @State private var eligibleItems: [Item] = []
    @State private var currentIndex = 0
    @State private var isRandomized = true
    @State private var includeBooks = true
    @State private var undoStack: [(item: Item, previousPlan: ItemPlan?)] = []
    @State private var showingExitConfirmation = false
    @State private var showingItemEditor = false
    @State private var editingItemName = ""
    @State private var showingMoveDestination = false
    @State private var selectedDestination: String = ""
    @State private var pendingMoveItem: Item?
    @State private var selectedLocationFilter: Location?
    @State private var showingLocationPicker = false
    
    private var currentItem: Item? {
        guard currentIndex < eligibleItems.count else { return nil }
        return eligibleItems[currentIndex]
    }
    
    private var progress: String {
        let remaining = eligibleItems.count - currentIndex
        return "\(remaining) item\(remaining == 1 ? "" : "s") remaining"
    }

    private var allDoneMessage: String {
        if let location = location {
            return "All items in \(location.name) have plans assigned"
        } else if let filter = selectedLocationFilter {
            return "All items in \(filter.name) have plans assigned"
        } else {
            return "All items have plans assigned"
        }
    }

    /// The effective location source for filtering items.
    private var effectiveLocation: Location? {
        location ?? selectedLocationFilter
    }
    
    var body: some View {
        NavigationStack {
            if eligibleItems.isEmpty {
                // No items to process
                ContentUnavailableView(
                    "All Done!",
                    systemImage: "checkmark.circle.fill",
                    description: Text(allDoneMessage)
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    if location == nil {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showingLocationPicker = true }) {
                                Label(selectedLocationFilter?.name ?? "All",
                                      systemImage: selectedLocationFilter == nil ? "map" : "mappin.circle.fill")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingLocationPicker) {
                    TinderLocationPickerView(
                        selectedLocation: selectedLocationFilter,
                        allLocations: allLocations,
                        allItems: allItems
                    ) { newFilter in
                        applyLocationFilter(newFilter)
                    }
                }
            } else if let item = currentItem {
                // Main Tinder interface
                VStack(spacing: 0) {
                    // Header with controls
                    HStack {
                        Button(action: { isRandomized.toggle(); reshuffle() }) {
                            Label(isRandomized ? "Random" : "A-Z", 
                                  systemImage: isRandomized ? "shuffle" : "textformat")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: { toggleIncludeBooks() }) {
                            Label(includeBooks ? "Books On" : "Books Off",
                                  systemImage: "books.vertical")
                                .font(.caption)
                                .foregroundColor(includeBooks ? .primary : .secondary)
                        }
                        .buttonStyle(.bordered)

                        if location == nil {
                            Button(action: { showingLocationPicker = true }) {
                                Label(selectedLocationFilter?.name ?? "All",
                                      systemImage: selectedLocationFilter == nil ? "map" : "mappin.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(selectedLocationFilter == nil ? .secondary : .primary)
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()
                        
                        Text(progress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Item display
                    VStack(spacing: 16) {
                        // Item name (tappable to edit)
                        Button(action: {
                            editingItemName = item.displayName
                            showingItemEditor = true
                        }) {
                            if item.isBook, let title = item.bookTitle, let author = item.bookAuthor {
                                VStack(spacing: 6) {
                                    Text(title)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                        .minimumScaleFactor(0.6)
                                    Text(author)
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                        .italic()
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.7)
                                }
                                .padding(.horizontal)
                                .foregroundColor(.primary)
                            } else {
                                Text(item.displayName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(4)
                                    .minimumScaleFactor(0.6)
                                    .padding(.horizontal)
                                    .foregroundColor(.primary)
                            }
                        }

                        // Location path
                        if let location = item.location {
                            Text(locationPath(for: location))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal)
                        }
                        
                        // Tags if any
                        if !item.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(item.tags) { tag in
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color(hex: tag.color) ?? .blue)
                                                .frame(width: 12, height: 12)
                                            Text(tag.name)
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(12)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Plan buttons with reordered layout
                    VStack(spacing: 8) {
                        ForEach([ItemPlan.keep, .sell, .charity, .fix], id: \.self) { plan in
                            Button(action: { applyPlan(plan) }) {
                                planButtonLabel(for: plan)
                            }
                        }

                        Button(action: { handleMovePlan() }) {
                            planButtonLabel(for: .move)
                        }

                        Button(action: { applyPlan(.throwAway) }) {
                            planButtonLabel(for: .throwAway)
                        }

                        // Undo button
                        if !undoStack.isEmpty {
                            Button(action: undo) {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward")
                                    Text("Undo")
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Quick Sort")
                            .font(.headline)
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Exit") { 
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Skip") { skipItem() }
                    }
                }
                .alert("Edit Item Name", isPresented: $showingItemEditor) {
                    TextField("Item Name", text: $editingItemName)
                    Button("Save") {
                        if let item = currentItem, !editingItemName.isEmpty {
                            guard let contextItem = allItems.first(where: { $0.id == item.id }) else { return }
                            let newName = editingItemName.trimmingCharacters(in: .whitespacesAndNewlines)

                            if contextItem.isBook {
                                // Try to parse "Title by Author"
                                if let byRange = newName.range(of: " by ", options: .caseInsensitive) {
                                    contextItem.bookTitle = String(newName[..<byRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                                    contextItem.bookAuthor = String(newName[byRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            }
                            contextItem.name = newName

                            if currentIndex < eligibleItems.count {
                                eligibleItems[currentIndex] = contextItem
                            }
                            saveChanges()
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                }
                .sheet(isPresented: $showingMoveDestination) {
                    MoveDestinationPicker(selectedDestination: $selectedDestination, item: pendingMoveItem) { destination in
                        if let item = pendingMoveItem {
                            // Find the actual item in the model context
                            if let contextItem = allItems.first(where: { $0.id == item.id }) {
                                // Store for undo
                                undoStack.append((item: contextItem, previousPlan: contextItem.plan))
                                
                                // Apply the move plan with destination
                                contextItem.plan = .move
                                contextItem.moveDestination = destination
                                saveChanges()
                                
                                // Update reference in eligibleItems if needed
                                if currentIndex < eligibleItems.count {
                                    eligibleItems[currentIndex] = contextItem
                                }
                                
                                // Move to next item
                                currentIndex += 1
                                pendingMoveItem = nil
                            } else {
                                print("❌ Could not find move item in model context")
                                pendingMoveItem = nil
                            }
                        }
                        showingMoveDestination = false
                    }
                }
                .sheet(isPresented: $showingLocationPicker) {
                    TinderLocationPickerView(
                        selectedLocation: selectedLocationFilter,
                        allLocations: allLocations,
                        allItems: allItems
                    ) { newFilter in
                        applyLocationFilter(newFilter)
                    }
                }
            } else {
                // Finished processing
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("All Done!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("You've sorted \(undoStack.count) item\(undoStack.count == 1 ? "" : "s")")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Button("Finish") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
            }
        }
        .onAppear {
            print("🎯 TinderModeView appeared")
            refreshItems()
        }
        .onDisappear {
            print("🚪 TinderModeView disappearing, forcing save...")
            // Force a final save when leaving
            do {
                try modelContext.save()
                print("💾 Final save on disappear successful")
            } catch {
                print("❌ Final save failed: \(error)")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func refreshItems() {
        print("🔄 Refreshing items list...")
        // Get items based on location context
        var items: [Item] = []

        if let loc = effectiveLocation {
            // Get items from this location and all sublocations
            items = getAllItemsRecursively(from: loc)
        } else {
            // Get all items directly from the query
            items = Array(allItems)
        }
        
        print("   Found \(items.count) total items")
        
        // Filter for items without plans
        items = items.filter { $0.plan == nil }
        
        print("   \(items.count) items without plans")
        
        // Filter books if needed
        if !includeBooks {
            items = items.filter { !$0.isBook }
        }
        
        // Sort or randomize
        if isRandomized {
            items.shuffle()
        } else {
            items.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
        
        eligibleItems = items
        currentIndex = 0
        print("   Eligible items set to \(eligibleItems.count) items")
        
        // Verify items are tracked by context
        for item in eligibleItems.prefix(3) {
            print("   Sample item: \(item.name), plan: \(item.plan?.rawValue ?? "nil")")
        }
    }
    
    private func reshuffle() {
        if isRandomized {
            eligibleItems.shuffle()
        } else {
            eligibleItems.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
        currentIndex = 0
        undoStack.removeAll()
    }
    
    private func getAllItemsRecursively(from location: Location) -> [Item] {
        var items = Array(location.items)
        for child in location.children {
            items.append(contentsOf: getAllItemsRecursively(from: child))
        }
        return items
    }
    
    private func applyPlan(_ plan: ItemPlan) {
        guard currentIndex < eligibleItems.count else { return }
        
        // Get the item reference
        let item = eligibleItems[currentIndex]
        
        // Find the actual item in the model context to ensure it's tracked
        guard let contextItem = allItems.first(where: { $0.id == item.id }) else {
            print("❌ Could not find item in model context")
            return
        }
        
        print("📝 Applying plan \(plan.rawValue) to item: \(contextItem.name)")
        print("   Item ID: \(contextItem.id)")
        print("   Current plan before change: \(contextItem.plan?.rawValue ?? "nil")")
        
        // Store for undo (using the context item)
        undoStack.append((item: contextItem, previousPlan: contextItem.plan))
        
        // Apply the plan to the context-tracked item
        contextItem.plan = plan
        
        // Clear move destination if changing from move plan
        if plan != .move {
            contextItem.moveDestination = nil
        }
        
        print("   Plan after assignment: \(contextItem.plan?.rawValue ?? "nil")")
        
        // Save immediately and verify
        saveChanges()
        
        // Verify the change persisted
        print("   ✅ After save, item plan is: \(contextItem.plan?.rawValue ?? "nil")")
        
        // Update the reference in eligibleItems
        eligibleItems[currentIndex] = contextItem
        
        // Move to next item
        currentIndex += 1
    }
    
    private func handleMovePlan() {
        guard let item = currentItem else { return }
        pendingMoveItem = item
        selectedDestination = item.moveDestination ?? ""
        showingMoveDestination = true
    }
    
    private func toggleIncludeBooks() {
        includeBooks.toggle()
        
        // Save current item to maintain position
        let currentItemId = currentItem?.id
        let wasAtIndex = currentIndex
        
        // Refresh the items list with new filter
        refreshItemsWithoutReset()
        
        // Try to maintain position intelligently
        if let currentId = currentItemId {
            // If current item still exists in the list, go to it
            if let newIndex = eligibleItems.firstIndex(where: { $0.id == currentId }) {
                currentIndex = newIndex
            } else {
                // Current item was filtered out (e.g., was a book and we're hiding books)
                // Reset to beginning since the list has changed significantly
                currentIndex = 0
            }
        } else {
            // No current item or we were at the end - reset to beginning
            currentIndex = 0
        }
        
        print("📚 Book filter toggled: \(includeBooks ? "including" : "excluding") books")
        print("   Current index: \(currentIndex) / \(eligibleItems.count)")
        print("   Items remaining: \(eligibleItems.count - currentIndex)")
    }

    private func applyLocationFilter(_ newFilter: Location?) {
        selectedLocationFilter = newFilter

        // Maintain position using same logic as toggleIncludeBooks
        let currentItemId = currentItem?.id

        refreshItemsWithoutReset()

        if let currentId = currentItemId,
           let newIndex = eligibleItems.firstIndex(where: { $0.id == currentId }) {
            currentIndex = newIndex
        } else {
            currentIndex = 0
        }

        print("📍 Location filter changed to: \(newFilter?.name ?? "All")")
        print("   Eligible items: \(eligibleItems.count)")
    }
    
    private func refreshItemsWithoutReset() {
        // Preserve the existing order rather than re-shuffling

        // Start with all items again
        var items: [Item] = []

        if let loc = effectiveLocation {
            // Get items from this location and all sublocations
            items = getAllItemsRecursively(from: loc)
        } else {
            // Get all items - make a copy of the array
            items = Array(allItems)
        }
        
        print("📋 RefreshItemsWithoutReset: Starting with \(items.count) total items")
        
        // Filter for items without plans
        items = items.filter { $0.plan == nil }
        print("   After filtering items without plans: \(items.count) items")
        
        // Store the current order of IDs if we have an existing list
        let existingOrder = eligibleItems.map { $0.id }
        
        // Filter books if needed
        if !includeBooks {
            let booksCount = items.filter { $0.isBook }.count
            items = items.filter { !$0.isBook }
            print("   Filtered out \(booksCount) books, remaining: \(items.count) items")
        } else {
            let booksCount = items.filter { $0.isBook }.count
            print("   Including \(booksCount) books in \(items.count) total items")
        }
        
        // If we had a previous order and are randomized, try to maintain relative positions
        if isRandomized && !existingOrder.isEmpty {
            // Sort items to match the existing order where possible
            items.sort { item1, item2 in
                let index1 = existingOrder.firstIndex(of: item1.id) ?? Int.max
                let index2 = existingOrder.firstIndex(of: item2.id) ?? Int.max
                return index1 < index2
            }
            
            // Add any new items (that weren't in the previous order) at the end, shuffled
            let newItems = items.filter { item in !existingOrder.contains(item.id) }
            if !newItems.isEmpty {
                var shuffledNew = newItems
                shuffledNew.shuffle()
                let existingItems = items.filter { item in existingOrder.contains(item.id) }
                items = existingItems + shuffledNew
            }
        } else if !isRandomized {
            // Sort alphabetically
            items.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
        
        eligibleItems = items
        print("   Final eligible items: \(eligibleItems.count)")
    }
    
    private func skipItem() {
        currentIndex += 1
    }
    
    private func undo() {
        guard !undoStack.isEmpty else { return }
        
        let lastAction = undoStack.removeLast()
        
        // Find the actual item in the model context
        guard let contextItem = allItems.first(where: { $0.id == lastAction.item.id }) else {
            print("❌ Could not find item to undo in model context")
            return
        }
        
        // Restore the previous plan
        contextItem.plan = lastAction.previousPlan
        
        // Save the undo action
        saveChanges()
        
        // Find the item in the list and go back to it
        if let index = eligibleItems.firstIndex(where: { $0.id == contextItem.id }) {
            currentIndex = index
        }
    }
    
    private func saveChanges() {
        do {
            if modelContext.hasChanges {
                try modelContext.save()
                print("💾 Successfully saved changes to model context")
            } else {
                print("⚠️ No changes to save in model context")
            }
        } catch {
            print("❌ Failed to save changes: \(error)")
        }
    }
    
    private func locationPath(for location: Location) -> String {
        var path: [String] = []
        var current: Location? = location
        
        while let loc = current {
            path.insert(loc.name, at: 0)
            current = loc.parent
        }
        
        return path.joined(separator: " › ")
    }
    
    // MARK: - Styling Functions
    
    private func planIcon(for plan: ItemPlan) -> Image {
        switch plan {
        case .keep:
            return Image(systemName: "heart.fill")
        case .throwAway:
            return Image(systemName: "trash.fill")
        case .sell:
            return Image(systemName: "dollarsign.circle.fill")
        case .charity:
            return Image(systemName: "gift.fill")
        case .move:
            return Image(systemName: "arrow.right.circle.fill")
        case .fix:
            return Image(systemName: "wrench.and.screwdriver.fill")
        }
    }
    
    private func planButtonColor(for plan: ItemPlan) -> Color {
        switch plan {
        case .keep:
            return .green
        case .throwAway:
            return .white
        case .sell:
            return .orange
        case .charity:
            return .purple
        case .move:
            return .blue
        case .fix:
            return .teal
        }
    }
    
    private func planButtonLabel(for plan: ItemPlan) -> some View {
        HStack {
            planIcon(for: plan)
                .font(.body)
            Text(plan.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
        }
        .foregroundColor(planButtonColor(for: plan))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(planButtonBackground(for: plan))
        .cornerRadius(10)
    }

    private func planButtonBackground(for plan: ItemPlan) -> Color {
        switch plan {
        case .keep:
            return Color.green.opacity(0.2)
        case .throwAway:
            return Color.red
        case .sell:
            return Color.orange.opacity(0.2)
        case .charity:
            return Color.purple.opacity(0.2)
        case .move:
            return Color.blue.opacity(0.2)
        case .fix:
            return Color.teal.opacity(0.2)
        }
    }
}

// MARK: - Tinder Location Picker

struct TinderLocationPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let selectedLocation: Location?
    let allLocations: [Location]
    let allItems: [Item]
    let onSelect: (Location?) -> Void

    @State private var expandedLocations: Set<UUID> = []

    private var topLevelLocations: [Location] {
        allLocations.filter { $0.parent == nil }.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                // "All Locations" option
                Button(action: {
                    onSelect(nil)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "map")
                            .foregroundColor(.accentColor)
                        Text("All Locations")
                        Spacer()
                        Text("\(unplannedCount(for: nil))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if selectedLocation == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .foregroundColor(.primary)

                // Location tree
                ForEach(buildLocationList(), id: \.location.id) { entry in
                    HStack {
                        // Indentation
                        ForEach(0..<entry.level, id: \.self) { _ in
                            Spacer().frame(width: 20)
                        }

                        // Expand/collapse chevron
                        if !entry.location.children.isEmpty {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedLocations.contains(entry.location.id) {
                                        expandedLocations.remove(entry.location.id)
                                    } else {
                                        expandedLocations.insert(entry.location.id)
                                    }
                                }
                            }) {
                                Image(systemName: expandedLocations.contains(entry.location.id)
                                      ? "chevron.down" : "chevron.right")
                                    .foregroundColor(.gray)
                                    .frame(width: 20)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Spacer().frame(width: 20)
                        }

                        // Location row
                        Button(action: {
                            onSelect(entry.location)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: entry.level == 0 ? "house" : "tray")
                                    .foregroundColor(.accentColor)
                                Text(entry.location.name)
                                Spacer()
                                Text("\(unplannedCount(for: entry.location))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if selectedLocation?.id == entry.location.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Filter by Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private struct LocationListEntry {
        let location: Location
        let level: Int
    }

    private func buildLocationList() -> [LocationListEntry] {
        var result: [LocationListEntry] = []

        func addLocation(_ location: Location, level: Int) {
            result.append(LocationListEntry(location: location, level: level))
            if expandedLocations.contains(location.id) {
                for child in location.children.sorted(by: { $0.name < $1.name }) {
                    addLocation(child, level: level + 1)
                }
            }
        }

        for topLevel in topLevelLocations {
            addLocation(topLevel, level: 0)
        }

        return result
    }

    private func unplannedCount(for location: Location?) -> Int {
        let items: [Item]
        if let location = location {
            items = getAllItemsRecursively(from: location)
        } else {
            items = allItems
        }
        return items.filter { $0.plan == nil }.count
    }

    private func getAllItemsRecursively(from location: Location) -> [Item] {
        var items = Array(location.items)
        for child in location.children {
            items.append(contentsOf: getAllItemsRecursively(from: child))
        }
        return items
    }
}