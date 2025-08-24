import SwiftUI
import SwiftData

struct TinderModeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let location: Location? // nil means all locations
    
    @Query private var allItems: [Item]
    
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
    
    private var currentItem: Item? {
        guard currentIndex < eligibleItems.count else { return nil }
        return eligibleItems[currentIndex]
    }
    
    private var progress: String {
        let remaining = eligibleItems.count - currentIndex
        return "\(remaining) item\(remaining == 1 ? "" : "s") remaining"
    }
    
    var body: some View {
        NavigationStack {
            if eligibleItems.isEmpty {
                // No items to process
                ContentUnavailableView(
                    "All Done!",
                    systemImage: "checkmark.circle.fill",
                    description: Text(location == nil ? 
                        "All items have plans assigned" : 
                        "All items in \(location?.name ?? "") have plans assigned")
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { dismiss() }
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
                        
                        Spacer()
                        
                        Text(progress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Item display
                    VStack(spacing: 24) {
                        // Item name (tappable to edit)
                        Button(action: {
                            editingItemName = item.displayName
                            showingItemEditor = true
                        }) {
                            Text(item.displayName)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .foregroundColor(.primary)
                        }
                        
                        // Location path
                        if let location = item.location {
                            Text(locationPath(for: location))
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // Item type indicator
                        if item.isBook {
                            HStack {
                                Image(systemName: "books.vertical.fill")
                                    .foregroundColor(.purple)
                                Text("Book")
                                    .foregroundColor(.purple)
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(20)
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
                    VStack(spacing: 12) {
                        // Keep button
                        Button(action: { applyPlan(.keep) }) {
                            HStack {
                                planIcon(for: .keep)
                                    .font(.title2)
                                Text(ItemPlan.keep.rawValue)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .foregroundColor(planButtonColor(for: .keep))
                            .padding()
                            .background(planButtonBackground(for: .keep))
                            .cornerRadius(12)
                        }
                        
                        // Sell button
                        Button(action: { applyPlan(.sell) }) {
                            HStack {
                                planIcon(for: .sell)
                                    .font(.title2)
                                Text(ItemPlan.sell.rawValue)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .foregroundColor(planButtonColor(for: .sell))
                            .padding()
                            .background(planButtonBackground(for: .sell))
                            .cornerRadius(12)
                        }
                        
                        // Charity button
                        Button(action: { applyPlan(.charity) }) {
                            HStack {
                                planIcon(for: .charity)
                                    .font(.title2)
                                Text(ItemPlan.charity.rawValue)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .foregroundColor(planButtonColor(for: .charity))
                            .padding()
                            .background(planButtonBackground(for: .charity))
                            .cornerRadius(12)
                        }
                        
                        // Fix button
                        Button(action: { applyPlan(.fix) }) {
                            HStack {
                                planIcon(for: .fix)
                                    .font(.title2)
                                Text(ItemPlan.fix.rawValue)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .foregroundColor(planButtonColor(for: .fix))
                            .padding()
                            .background(planButtonBackground(for: .fix))
                            .cornerRadius(12)
                        }
                        
                        // Move button (triggers destination selector)
                        Button(action: { handleMovePlan() }) {
                            HStack {
                                planIcon(for: .move)
                                    .font(.title2)
                                Text(ItemPlan.move.rawValue)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .foregroundColor(planButtonColor(for: .move))
                            .padding()
                            .background(planButtonBackground(for: .move))
                            .cornerRadius(12)
                        }
                        
                        // Throw Away button (moved down)
                        Button(action: { applyPlan(.throwAway) }) {
                            HStack {
                                planIcon(for: .throwAway)
                                    .font(.title2)
                                Text(ItemPlan.throwAway.rawValue)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .foregroundColor(planButtonColor(for: .throwAway))
                            .padding()
                            .background(planButtonBackground(for: .throwAway))
                            .cornerRadius(12)
                        }
                        
                        // Undo button
                        if !undoStack.isEmpty {
                            Button(action: undo) {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward")
                                    Text("Undo")
                                }
                                .foregroundColor(.blue)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
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
                            item.name = editingItemName
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
        
        if let location = location {
            // Get items from this location and all sublocations
            items = getAllItemsRecursively(from: location)
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
    
    private func refreshItemsWithoutReset() {
        // This function is only called when toggling book filter
        // We should preserve the existing order rather than re-shuffling
        
        // Start with all items again
        var items: [Item] = []
        
        if let location = location {
            // Get items from this location and all sublocations
            items = getAllItemsRecursively(from: location)
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