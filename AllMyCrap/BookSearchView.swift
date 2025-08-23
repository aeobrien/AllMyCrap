import SwiftUI
import SwiftData

struct BookSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Item> { $0.isBook == true }) private var books: [Item]
    
    @State private var searchText = ""
    @State private var sortBy: SortOption = .title
    @State private var groupBy: GroupOption = .none
    
    enum SortOption: String, CaseIterable {
        case title = "Title"
        case author = "Author"
        case dateAdded = "Date Added"
        case location = "Location"
        
        var keyPath: KeyPath<Item, String> {
            switch self {
            case .title: return \.bookTitle!
            case .author: return \.bookAuthor!
            case .dateAdded: return \.dateAdded.description
            case .location: return \.location!.name
            }
        }
    }
    
    enum GroupOption: String, CaseIterable {
        case none = "No Grouping"
        case author = "By Author"
        case location = "By Location"
    }
    
    private var filteredBooks: [Item] {
        let filtered = searchText.isEmpty ? books : books.filter { book in
            let title = book.bookTitle?.lowercased() ?? ""
            let author = book.bookAuthor?.lowercased() ?? ""
            let search = searchText.lowercased()
            return title.contains(search) || author.contains(search)
        }
        
        return filtered.sorted { first, second in
            switch sortBy {
            case .title:
                return (first.bookTitle ?? "") < (second.bookTitle ?? "")
            case .author:
                return (first.bookAuthor ?? "") < (second.bookAuthor ?? "")
            case .dateAdded:
                return first.dateAdded > second.dateAdded
            case .location:
                return (first.location?.name ?? "") < (second.location?.name ?? "")
            }
        }
    }
    
    private var groupedBooks: [(key: String, books: [Item])] {
        guard groupBy != .none else {
            return [("", filteredBooks)]
        }
        
        let grouped = Dictionary(grouping: filteredBooks) { book in
            switch groupBy {
            case .author:
                return book.bookAuthor ?? "Unknown Author"
            case .location:
                return book.location?.name ?? "Unknown Location"
            case .none:
                return ""
            }
        }
        
        return grouped.sorted { $0.key < $1.key }.map { (key: $0.key, books: $0.value) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if books.isEmpty {
                    ContentUnavailableView(
                        "No Books",
                        systemImage: "books.vertical",
                        description: Text("Add books to see them here")
                    )
                } else if filteredBooks.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(groupedBooks, id: \.key) { group in
                        if groupBy != .none {
                            Section(group.key) {
                                booksList(group.books)
                            }
                        } else {
                            booksList(group.books)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search books by title or author")
            .navigationTitle("Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Section("Sort By") {
                            Picker("Sort By", selection: $sortBy) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        }
                        
                        Section("Group By") {
                            Picker("Group By", selection: $groupBy) {
                                ForEach(GroupOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func booksList(_ books: [Item]) -> some View {
        ForEach(books) { book in
            VStack(alignment: .leading, spacing: 4) {
                Text(book.bookTitle ?? "Unknown Title")
                    .font(.headline)
                
                Text("by \(book.bookAuthor ?? "Unknown Author")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let location = book.location {
                    HStack {
                        Image(systemName: "location")
                            .font(.caption2)
                        Text(locationPath(for: location))
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                
                if !book.tags.isEmpty {
                    HStack {
                        Image(systemName: "tag")
                            .font(.caption2)
                        Text(book.tags.map { $0.name }.joined(separator: ", "))
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    private func locationPath(for location: Location) -> String {
        var path: [String] = []
        var current: Location? = location
        
        while let loc = current {
            path.insert(loc.name, at: 0)
            current = loc.parent
        }
        
        return path.joined(separator: " > ")
    }
}