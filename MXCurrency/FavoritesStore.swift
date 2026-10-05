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
        pairs.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(pairs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
