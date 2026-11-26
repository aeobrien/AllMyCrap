import SwiftUI
import SwiftData

struct MoveDestinationPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Location.name) private var allLocations: [Location]
    
    @Binding var selectedDestination: String
    let item: Item?
    let onConfirm: (String) -> Void
    
    @State private var customDestination = ""
    @State private var selectedLocation: Location?
    @State private var useCustomDestination = false
    @State private var expandedLocations: Set<UUID> = []
    
    init(selectedDestination: Binding<String>, item: Item?, onConfirm: @escaping (String) -> Void) {
        self._selectedDestination = selectedDestination
        self.item = item
        self.onConfirm = onConfirm
        print("🔵 MoveDestinationPicker init with item: \(item?.name ?? "nil")")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Destination Type") {
                    Picker("Destination", selection: $useCustomDestination) {
                        Text("Select Location").tag(false)
                        Text("Custom Destination").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                
                if useCustomDestination {
                    Section("Custom Destination") {
                        TextField("e.g., 'Give to John', 'Storage unit'", text: $customDestination)
                    }
                } else {
                    Section("Select Location") {
                        let _ = print("🔴 Section rendering with \(topLevelLocations.count) top-level locations")
                        // Use a ScrollView instead of nested ForEach for better state management
                        ForEach(Array(buildLocationList()), id: \.location.id) { item in
                            LocationItemRow(
                                location: item.location,
                                level: item.level,
                                selectedLocation: $selectedLocation,
                                expandedLocations: $expandedLocations
                            )
                        }
                    }
                }
                
                if let item = item {
                    Section("Moving Item") {
                        HStack {
                            Image(systemName: "shippingbox")
                                .foregroundColor(.accentColor)
                            Text(item.displayName)
                                .font(.headline)
                        }
                    }
                }
            }
            .navigationTitle("Move Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirm") {
                        let destination: String
                        if useCustomDestination {
                            destination = customDestination
                        } else if let location = selectedLocation {
                            destination = fullPath(for: location)
                        } else {
                            destination = ""
                        }
                        
                        if !destination.isEmpty {
                            onConfirm(destination)
                        }
                    }
                    .disabled(useCustomDestination ? customDestination.isEmpty : selectedLocation == nil)
                }
            }
        }
        .onAppear {
            // Try to parse existing destination
            if !selectedDestination.isEmpty {
                // Check if it matches a location path
                if let location = findLocationByPath(selectedDestination) {
                    selectedLocation = location
                    useCustomDestination = false
                } else {
                    useCustomDestination = true
                    customDestination = selectedDestination
                }
            }
        }
    }
    
    private var topLevelLocations: [Location] {
        allLocations.filter { $0.parent == nil }.sorted { $0.name < $1.name }
    }
    
    private struct LocationListItem {
        let location: Location
        let level: Int
    }
    
    private func buildLocationList() -> [LocationListItem] {
        var result: [LocationListItem] = []
        
        func addLocation(_ location: Location, level: Int) {
            result.append(LocationListItem(location: location, level: level))
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
    
    private func findLocationByPath(_ path: String) -> Location? {
        // Try to find a location matching the path
        for location in allLocations {
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
}

struct LocationItemRow: View {
    let location: Location
    let level: Int
    @Binding var selectedLocation: Location?
    @Binding var expandedLocations: Set<UUID>
    
    var body: some View {
        HStack {
            // Indentation
            ForEach(0..<level, id: \.self) { _ in
                Spacer()
                    .frame(width: 20)
            }
            
            // Expansion chevron if has children
            if !location.children.isEmpty {
                Button(action: { 
                    print("🔶 Chevron tapped for \(location.name)")
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedLocations.contains(location.id) {
                            print("  - Removing from expanded set")
                            expandedLocations.remove(location.id)
                        } else {
                            print("  - Adding to expanded set")
                            expandedLocations.insert(location.id)
                        }
                    }
                    print("  - Expanded locations now: \(expandedLocations.count) items")
                }) {
                    Image(systemName: expandedLocations.contains(location.id) ? "chevron.down" : "chevron.right")
                        .foregroundColor(.gray)
                        .frame(width: 20)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Spacer()
                    .frame(width: 20)
            }
            
            // Location button
            Button(action: {
                print("🟢 Location selected: \(location.name) at level \(level)")
                selectedLocation = location
                print("  - Selected location is now: \(selectedLocation?.name ?? "nil")")
            }) {
                HStack {
                    Image(systemName: level == 0 ? "house" : "tray")
                        .foregroundColor(selectedLocation?.id == location.id ? .white : .accentColor)
                    
                    Text(location.name)
                        .foregroundColor(selectedLocation?.id == location.id ? .white : .primary)
                    
                    Spacer()
                    
                    if selectedLocation?.id == location.id {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedLocation?.id == location.id ? Color.accentColor : Color(.systemGray6))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

