import SwiftUI
import SwiftData

struct BookDetectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allItems: [Item]
    @Query private var allTags: [Tag]
    
    @State private var potentialBooks: [PotentialBook] = []
    @State private var selectedBooks: Set<UUID> = []
    @State private var isProcessing = false
    @State private var conversionComplete = false
    @State private var convertedCount = 0
    
    struct PotentialBook: Identifiable {
        let id = UUID()
        let item: Item
        let proposedTitle: String
        let proposedAuthor: String
        let reason: String  // "Tagged as book" or "Contains 'by'"
    }
    
    var body: some View {
        NavigationStack {
            if conversionComplete {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Conversion Complete")
                        .font(.title)
                    
                    Text("\(convertedCount) item\(convertedCount == 1 ? "" : "s") converted to books")
                        .foregroundColor(.secondary)
                    
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if potentialBooks.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("No Potential Books Found")
                        .font(.title2)
                    
                    Text("No items were found that could be converted to books.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                List {
                    Section {
                        ForEach(potentialBooks) { book in
                            HStack {
                                Image(systemName: selectedBooks.contains(book.id) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedBooks.contains(book.id) ? .accentColor : .gray)
                                    .onTapGesture {
                                        if selectedBooks.contains(book.id) {
                                            selectedBooks.remove(book.id)
                                        } else {
                                            selectedBooks.insert(book.id)
                                        }
                                    }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.item.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        Text("Title:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(book.proposedTitle)
                                            .fontWeight(.medium)
                                    }
                                    
                                    HStack {
                                        Text("Author:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(book.proposedAuthor)
                                    }
                                    
                                    Text(book.reason)
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                                
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedBooks.contains(book.id) {
                                    selectedBooks.remove(book.id)
                                } else {
                                    selectedBooks.insert(book.id)
                                }
                            }
                        }
                    } header: {
                        Text("Select items to convert to books")
                    } footer: {
                        Text("\(selectedBooks.count) of \(potentialBooks.count) selected")
                    }
                }
                .navigationTitle("Detect Books")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Convert") {
                            convertSelectedBooks()
                        }
                        .disabled(selectedBooks.isEmpty || isProcessing)
                    }
                    
                    ToolbarItem(placement: .bottomBar) {
                        HStack {
                            Button("Select All") {
                                selectedBooks = Set(potentialBooks.map { $0.id })
                            }
                            
                            Spacer()
                            
                            if !selectedBooks.isEmpty {
                                Button("Clear Selection") {
                                    selectedBooks.removeAll()
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            detectPotentialBooks()
        }
        .overlay {
            if isProcessing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Converting...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
    }
    
    private func detectPotentialBooks() {
        var books: [PotentialBook] = []
        
        // Find book tag if it exists
        let bookTags = allTags.filter { tag in
            tag.name.lowercased().contains("book")
        }
        
        for item in allItems {
            // Skip if already a book
            if item.isBook {
                continue
            }
            
            // Check if tagged as book
            let hasBookTag = item.tags.contains { tag in
                bookTags.contains { $0.id == tag.id }
            }
            
            // Try to extract title and author
            if let (title, author) = extractTitleAndAuthor(from: item.name) {
                let reason = hasBookTag ? "Tagged as book" : "Contains 'by'"
                books.append(PotentialBook(
                    item: item,
                    proposedTitle: title,
                    proposedAuthor: author,
                    reason: reason
                ))
            } else if hasBookTag {
                // Tagged as book but no "by" - use the whole name as title
                books.append(PotentialBook(
                    item: item,
                    proposedTitle: item.name,
                    proposedAuthor: "Unknown",
                    reason: "Tagged as book"
                ))
            }
        }
        
        potentialBooks = books
        
        // Auto-select all items that are tagged as books
        selectedBooks = Set(books.filter { $0.reason == "Tagged as book" }.map { $0.id })
    }
    
    private func extractTitleAndAuthor(from name: String) -> (title: String, author: String)? {
        // Look for " by " (case insensitive)
        let lowercased = name.lowercased()
        if let byRange = lowercased.range(of: " by ") {
            let titleEndIndex = name.index(name.startIndex, offsetBy: name.distance(from: name.startIndex, to: byRange.lowerBound))
            let authorStartIndex = name.index(name.startIndex, offsetBy: name.distance(from: name.startIndex, to: byRange.upperBound))
            
            let title = String(name[..<titleEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let author = String(name[authorStartIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !title.isEmpty && !author.isEmpty {
                return (title, author)
            }
        }
        
        return nil
    }
    
    private func convertSelectedBooks() {
        isProcessing = true
        
        Task {
            let selectedPotentialBooks = potentialBooks.filter { selectedBooks.contains($0.id) }
            
            for potentialBook in selectedPotentialBooks {
                let item = potentialBook.item
                item.isBook = true
                item.bookTitle = potentialBook.proposedTitle
                item.bookAuthor = potentialBook.proposedAuthor
                item.name = "\(potentialBook.proposedTitle) by \(potentialBook.proposedAuthor)"
            }
            
            do {
                try modelContext.save()
                
                await MainActor.run {
                    convertedCount = selectedPotentialBooks.count
                    conversionComplete = true
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    // Handle error - you might want to show an alert here
                    print("Failed to convert books: \(error)")
                }
            }
        }
    }
}