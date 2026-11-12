import Foundation

struct DuplicateCandidate {
    let id: UUID
    let name: String
    let isBook: Bool
    let bookTitle: String?
    let bookAuthor: String?
    let locationPath: String
}

struct DuplicateMatch: Identifiable {
    let id: UUID
    let name: String
    let locationPath: String
    let score: Double
}

struct DuplicateMatcher {

    // MARK: - Public API

    /// Check a single item name (or book) against a list of candidates.
    /// Returns matches that exceed the similarity threshold.
    static func findDuplicates(
        name: String,
        isBook: Bool,
        bookTitle: String? = nil,
        bookAuthor: String? = nil,
        candidates: [DuplicateCandidate],
        threshold: Double = 0.75
    ) -> [DuplicateMatch] {
        candidates.compactMap { candidate in
            let score: Double

            if isBook, let title = bookTitle, let author = bookAuthor {
                score = bookSimilarity(
                    title: title, author: author,
                    candidate: candidate
                )
            } else {
                score = bestSimilarity(between: name, and: candidate.name)
            }

            guard score >= threshold else { return nil }
            return DuplicateMatch(
                id: candidate.id,
                name: candidate.name,
                locationPath: candidate.locationPath,
                score: score
            )
        }
    }

    // MARK: - Similarity Strategies

    /// Returns the highest score from three strategies.
    static func bestSimilarity(between a: String, and b: String) -> Double {
        let normA = normalize(a)
        let normB = normalize(b)
        let lowA = a.lowercased()
        let lowB = b.lowercased()

        let s1 = levenshteinSimilarity(normA, normB)
        let s2 = levenshteinSimilarity(lowA, lowB)
        let s3 = jaccardSimilarity(normA, normB)

        return max(s1, s2, s3)
    }

    // MARK: - Normalization

    /// Master normalization pipeline:
    /// lowercase -> strip leading articles -> number words to digits ->
    /// strip punctuation -> collapse whitespace
    static func normalize(_ input: String) -> String {
        var s = input.lowercased()

        // Strip leading articles
        for article in ["the ", "a ", "an "] {
            if s.hasPrefix(article) {
                s = String(s.dropFirst(article.count))
                break
            }
        }

        // Number words to digits
        s = replaceNumberWords(in: s)

        // Strip punctuation (keep alphanumeric and spaces)
        s = s.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || CharacterSet.whitespaces.contains($0)
        }.map { String($0) }.joined()

        // Collapse whitespace
        s = s.split(separator: " ").joined(separator: " ")

        return s
    }

    // MARK: - Book Matching

    /// For books, compare title and author separately. Both must meet 0.7 threshold.
    /// Also attempts to parse "Title by Author" from non-book candidates.
    private static func bookSimilarity(
        title: String,
        author: String,
        candidate: DuplicateCandidate
    ) -> Double {
        let candidateTitle: String
        let candidateAuthor: String

        if candidate.isBook, let ct = candidate.bookTitle, let ca = candidate.bookAuthor {
            candidateTitle = ct
            candidateAuthor = ca
        } else if let byRange = candidate.name.range(of: " by ", options: .caseInsensitive) {
            candidateTitle = String(candidate.name[..<byRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            candidateAuthor = String(candidate.name[byRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Can't compare as book, fall back to full-name similarity
            let fullName = "\(title) by \(author)"
            return bestSimilarity(between: fullName, and: candidate.name)
        }

        let titleScore = bestSimilarity(between: title, and: candidateTitle)
        let authorScore = bestSimilarity(between: author, and: candidateAuthor)

        // Both must meet 0.7 threshold
        guard titleScore >= 0.7 && authorScore >= 0.7 else { return 0.0 }

        // Return average as final score
        return (titleScore + authorScore) / 2.0
    }

    // MARK: - Levenshtein

    static func levenshteinSimilarity(_ a: String, _ b: String) -> Double {
        let distance = levenshteinDistance(a, b)
        let maxLength = max(a.count, b.count)
        return maxLength == 0 ? 1.0 : 1.0 - (Double(distance) / Double(maxLength))
    }

    static func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let m = aChars.count
        let n = bChars.count

        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                if aChars[i - 1] == bChars[j - 1] {
                    curr[j] = prev[j - 1]
                } else {
                    curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + 1)
                }
            }
            swap(&prev, &curr)
        }

        return prev[n]
    }

    // MARK: - Jaccard (Token-Set)

    /// Order-independent word-overlap similarity.
    static func jaccardSimilarity(_ a: String, _ b: String) -> Double {
        let setA = Set(a.split(separator: " ").map { String($0) })
        let setB = Set(b.split(separator: " ").map { String($0) })

        guard !setA.isEmpty || !setB.isEmpty else { return 1.0 }

        let intersection = setA.intersection(setB).count
        let union = setA.union(setB).count

        return Double(intersection) / Double(union)
    }

    // MARK: - Number Word Replacement

    private static func replaceNumberWords(in text: String) -> String {
        let replacements: [(String, String)] = [
            ("thousand", "1000"),
            ("hundred", "100"),
            ("ninety", "90"),
            ("eighty", "80"),
            ("seventy", "70"),
            ("sixty", "60"),
            ("fifty", "50"),
            ("forty", "40"),
            ("thirty", "30"),
            ("twenty", "20"),
            ("nineteen", "19"),
            ("eighteen", "18"),
            ("seventeen", "17"),
            ("sixteen", "16"),
            ("fifteen", "15"),
            ("fourteen", "14"),
            ("thirteen", "13"),
            ("twelve", "12"),
            ("eleven", "11"),
            ("ten", "10"),
            ("nine", "9"),
            ("eight", "8"),
            ("seven", "7"),
            ("six", "6"),
            ("five", "5"),
            ("four", "4"),
            ("three", "3"),
            ("two", "2"),
            ("one", "1"),
            ("zero", "0"),
        ]

        var result = text
        for (word, digit) in replacements {
            // Use word boundary matching to avoid replacing partial words
            result = result.replacingOccurrences(
                of: "\\b\(word)\\b",
                with: digit,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return result
    }
}
