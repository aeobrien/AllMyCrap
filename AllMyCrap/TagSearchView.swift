import SwiftUI
import SwiftData

struct TagSearchView: View {
    @Query private var tags: [Tag]
    @State private var selectedTag: Tag?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(tags.sorted { $0.name < $1.name }) { tag in
                    NavigationLink(destination: TagItemsView(tag: tag)) {
                        HStack {
                            Circle()
                                .fill(Color(hex: tag.color) ?? .blue)
                                .frame(width: 20, height: 20)
                            Text(tag.name)
                            Spacer()
                            Text("\(tag.items.count) items")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Browse by Tag")
        }
    }
}

struct TagItemsView: View {
    let tag: Tag
    
    var body: some View {
        List {
            ForEach(tag.items.sorted { $0.name < $1.name }) { item in
                NavigationLink(value: item.location) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.body)
                        
                        if let location = item.location {
                            Text(pathToLocation(location))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(tag.name)
        .navigationDestination(for: Location.self) { location in
            LocationDetailView(location: location)
        }
    }
    
    private func pathToLocation(_ location: Location) -> String {
        var path: [String] = []
        var current: Location? = location
        
        while let loc = current {
            path.insert(loc.name, at: 0)
            current = loc.parent
        }
        
        return path.joined(separator: " → ")
    }
}