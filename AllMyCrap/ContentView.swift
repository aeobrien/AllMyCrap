import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    // Top-level rooms (no parent)
    @Query(filter: #Predicate<Location> { $0.parent == nil },
           sort: \.name) private var rooms: [Location]

    @State private var isAddingRoom = false
    @State private var isSearching  = false
    @State private var showingSettings = false
    @State private var showingTagSearch = false
    @State private var showingPlanSearch = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(rooms) { room in
                    NavigationLink(value: room) { Text(room.name) }
                }
                .onDelete(perform: deleteRooms)
            }
            .navigationTitle("All My Crap")
            .navigationDestination(for: Location.self) { LocationDetailView(location: $0) }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("Search by Name", systemImage: "magnifyingglass") {
                            isSearching = true
                        }
                        Button("Browse by Tag", systemImage: "tag") {
                            showingTagSearch = true
                        }
                        Button("Browse by Plan", systemImage: "list.bullet.rectangle") {
                            showingPlanSearch = true
                        }
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add Room", systemImage: "plus") {
                            isAddingRoom = true
                        }
                        Button("Settings", systemImage: "gear") {
                            showingSettings = true
                        }
                    } label: {
                        Label("Menu", systemImage: "ellipsis.circle")
                    }
                }
            }
            .overlay {
                if rooms.isEmpty {
                    ContentUnavailableView("No Rooms",
                                           systemImage: "house.fill",
                                           description: Text("Tap '+' to add your first room."))
                }
            }
            .sheet(isPresented: $isAddingRoom) { LocationEditView(location: nil, parentLocation: nil) }
            .sheet(isPresented: $isSearching)  { SearchView() }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingTagSearch) {
                TagSearchView()
            }
            .sheet(isPresented: $showingPlanSearch) {
                PlanSearchView()
            }
        }
    }

    private func deleteRooms(offsets: IndexSet) {
        withAnimation { offsets.forEach { modelContext.delete(rooms[$0]) } }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Location.self, Item.self, Tag.self, ReviewHistory.self], inMemory: true)
}
