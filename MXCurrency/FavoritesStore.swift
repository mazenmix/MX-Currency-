import Foundation

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var pairs: [CurrencyPair] = []

    private let key = "mx.currency.favoritePairs"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([CurrencyPair].self, from: data) {
            pairs = decoded
        } else {
            pairs = [
                CurrencyPair(from: "USD", to: "PHP"),
                CurrencyPair(from: "USD", to: "IQD"),
                CurrencyPair(from: "USD", to: "IDR"),
                CurrencyPair(from: "USD", to: "TRY"),
                CurrencyPair(from: "USD", to: "THB"),
                CurrencyPair(from: "USD", to: "VND")
            ]
            save()
        }
    }

    func contains(_ pair: CurrencyPair) -> Bool {
        pairs.contains(pair)
    }

    func toggle(_ pair: CurrencyPair) {
        if let index = pairs.firstIndex(of: pair) {
            pairs.remove(at: index)
        } else {
            pairs.insert(pair, at: 0)
        }
        save()
    }

    func add(_ pair: CurrencyPair) {
        guard pair.from != pair.to, !pairs.contains(pair) else { return }
        pairs.insert(pair, at: 0)
        save()
    }

    func remove(_ pair: CurrencyPair) {
        guard let index = pairs.firstIndex(of: pair) else { return }
        pairs.remove(at: index)
        save()
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where pairs.indices.contains(index) {
            pairs.remove(at: index)
        }
        save()
    }

    func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let validOffsets = offsets.filter { pairs.indices.contains($0) }
        guard !validOffsets.isEmpty else { return }

        let movingItems = validOffsets.sorted().map { pairs[$0] }
        var adjustedDestination = destination

        for index in validOffsets.sorted(by: >) {
            pairs.remove(at: index)
            if index < destination {
                adjustedDestination -= 1
            }
        }

        adjustedDestination = max(0, min(adjustedDestination, pairs.count))
        pairs.insert(contentsOf: movingItems, at: adjustedDestination)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(pairs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
