import SwiftUI
import SwiftData

struct PlanSearchView: View {
    @Query private var items: [Item]
    
    private var itemsByPlan: [(ItemPlan, [Item])] {
        var result: [(ItemPlan, [Item])] = []
        
        // Group items by plan
        let grouped = Dictionary(grouping: items.filter { $0.plan != nil }) { $0.plan! }
        
        // Add all plans, even if empty
        for plan in ItemPlan.allCases {
            let planItems = grouped[plan] ?? []
            result.append((plan, planItems.sorted { $0.name < $1.name }))
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(itemsByPlan, id: \.0) { plan, planItems in
                    NavigationLink(destination: PlanItemsView(plan: plan, items: planItems)) {
                        HStack {
                            planIcon(for: plan)
                                .foregroundColor(planColor(for: plan))
                                .frame(width: 30)
                            Text(plan.rawValue)
                            Spacer()
                            Text("\(planItems.count) items")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Browse by Plan")
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
}

struct PlanItemsView: View {
    let plan: ItemPlan
    let items: [Item]
    
    var body: some View {
        List {
            ForEach(items) { item in
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
        .navigationTitle(plan.rawValue)
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