import SwiftUI
import SwiftData

/// Add or edit a Location (room / container).
struct LocationEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    /// Existing location to edit (nil == new)
    var location: Location?
    /// Where the new location will sit (nil for rooms)
    var parentLocation: Location?

    @State private var name = ""
    @State private var showDepthAlert = false

    var body: some View {
        NavigationStack {
            Form { TextField("Name", text: $name) }
                .navigationTitle(location == nil ? "Add Location" : "Edit Location")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: save).disabled(name.isEmpty)
                    }
                }
                .onAppear { if let location { name = location.name } }
                .alert("Hierarchy too deep",
                       isPresented: $showDepthAlert,
                       actions: { Button("OK", role: .cancel) { } },
                       message: { Text("Locations are limited to 15 levels.") })
        }
    }

    private func save() {
        // Depth cap for new containers
        if location == nil, (parentLocation?.depth ?? 0) >= 15 {
            showDepthAlert = true
            return
        }

        if let location {
            location.name = name
        } else {
            modelContext.insert(Location(name: name, parent: parentLocation))
        }
        dismiss()
    }
}
