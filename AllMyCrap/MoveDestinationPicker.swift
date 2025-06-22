import SwiftUI
import SwiftData

/// Simple list picker used for “Move To…”.
struct MoveDestinationPicker: View {
    @Environment(\.dismiss) private var dismiss

    /// IDs that must not appear as selectable destinations
    let forbiddenIDs: Set<UUID>
    /// Callback once a destination is chosen
    let onSelect: (Location) -> Void

    @Query(sort: \Location.name) private var allLocations: [Location]

    var body: some View {
        NavigationStack {
            List {
                ForEach(allLocations.filter { !forbiddenIDs.contains($0.id) }) { loc in
                    Button {
                        onSelect(loc)
                        dismiss()
                    } label: {
                        Text(fullPath(for: loc))
                    }
                    // Block selecting a level that would exceed the 15-deep cap
                    .disabled(loc.depth >= 15)
                }
            }
            .navigationTitle("Move To…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func fullPath(for location: Location) -> String {
        var parts = [location.name]
        var current = location.parent
        while let next = current { parts.append(next.name); current = next.parent }
        return parts.reversed().joined(separator: " › ")
    }
}
