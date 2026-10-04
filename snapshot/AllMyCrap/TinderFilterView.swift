import SwiftUI
import SwiftData

enum TinderPlanFilter: Equatable {
    case unplanned
    case all
    case plan(ItemPlan)
}

struct TinderFilterView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var filterPlan: TinderPlanFilter
    @Binding var filterTag: Tag?
    @Binding var includeBooks: Bool

    let allTags: [Tag]

    var body: some View {
        NavigationStack {
            List {
                Section("Plan Filter") {
                    Button {
                        filterPlan = .unplanned
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            Text("Unplanned Only")
                            Spacer()
                            if filterPlan == .unplanned {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)

                    Button {
                        filterPlan = .all
                    } label: {
                        HStack {
                            Image(systemName: "tray.full")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("All Items")
                            Spacer()
                            if filterPlan == .all {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)

                    ForEach(ItemPlan.allCases, id: \.self) { plan in
                        Button {
                            filterPlan = .plan(plan)
                        } label: {
                            HStack {
                                planIcon(for: plan)
                                    .foregroundColor(planColor(for: plan))
                                    .frame(width: 24)
                                Text(plan.rawValue)
                                Spacer()
                                if filterPlan == .plan(plan) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                Section("Tag Filter") {
                    Button {
                        filterTag = nil
                    } label: {
                        HStack {
                            Text("No Filter")
                            Spacer()
                            if filterTag == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)

                    ForEach(allTags.sorted { $0.name < $1.name }) { tag in
                        Button {
                            filterTag = tag
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(hex: tag.color) ?? .blue)
                                    .frame(width: 14, height: 14)
                                Text(tag.name)
                                Spacer()
                                if filterTag?.id == tag.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                Section("Other") {
                    Toggle("Include Books", isOn: $includeBooks)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func planIcon(for plan: ItemPlan) -> some View {
        switch plan {
        case .keep: Image(systemName: "heart.fill")
        case .throwAway: Image(systemName: "trash.fill")
        case .sell: Image(systemName: "dollarsign.circle.fill")
        case .charity: Image(systemName: "gift.fill")
        case .move: Image(systemName: "arrow.right.circle.fill")
        case .fix: Image(systemName: "wrench.and.screwdriver.fill")
        }
    }

    private func planColor(for plan: ItemPlan) -> Color {
        switch plan {
        case .keep: return .green
        case .throwAway: return .red
        case .sell: return .orange
        case .charity: return .purple
        case .move: return .blue
        case .fix: return .teal
        }
    }
}
