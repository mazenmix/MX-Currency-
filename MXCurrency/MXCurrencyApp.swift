import SwiftUI

@main
struct MXCurrencyApp: App {
    @StateObject private var rates = RateService()
    @StateObject private var favorites = FavoritesStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(rates)
                .environmentObject(favorites)
                .preferredColorScheme(.dark)
        }
    }
}
