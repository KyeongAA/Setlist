import Foundation

struct RecentSearchHistory {
    private let defaults: UserDefaults
    private let storageKey = "setlist.recentSearchKeywords"
    private let maximumCount = 10

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [String] {
        defaults.stringArray(forKey: storageKey) ?? []
    }

    @discardableResult
    func record(_ rawQuery: String) -> [String] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return load() }

        var keywords = load().filter {
            $0.caseInsensitiveCompare(query) != .orderedSame
        }
        keywords.insert(query, at: 0)
        keywords = Array(keywords.prefix(maximumCount))
        defaults.set(keywords, forKey: storageKey)
        return keywords
    }
}
