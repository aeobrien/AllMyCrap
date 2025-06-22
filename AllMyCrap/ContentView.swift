import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    // Top-level rooms (no parent)
    @Query(filter: #Predicate<Location> { $0.parent == nil },
           sort: \.name) private var rooms: [Location]

    @State private var isAddingRoom = false
    @State private var isSearching  = false

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
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { isSearching = true }      label: { Image(systemName: "magnifyingglass") }
                    Button { isAddingRoom = true }    label: { Label("Add Room", systemImage: "plus") }
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
        }
    }

    private func deleteRooms(offsets: IndexSet) {
        withAnimation { offsets.forEach { modelContext.delete(rooms[$0]) } }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Location.self, Item.self], inMemory: true)
}
