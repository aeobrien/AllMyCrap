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
    
    @Query private var allReviewHistory: [ReviewHistory]
    
    private var locationReviewHistory: [ReviewHistory] {
        guard let location else { return [] }
        return allReviewHistory
            .filter { $0.location?.id == location.id }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                
                if let location, !locationReviewHistory.isEmpty {
                    Section("Review History") {
                        ForEach(locationReviewHistory) { history in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(history.action.rawValue)
                                        .font(.body)
                                    Text(history.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if history.isAutomatic {
                                    Text("Auto")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            }
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
