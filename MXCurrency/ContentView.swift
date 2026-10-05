import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var rates: RateService
    @EnvironmentObject private var favorites: FavoritesStore

    @State private var from = CurrencyCatalog.currency("USD")
    @State private var to = CurrencyCatalog.currency("PHP")
    @State private var amountText = ""
    @State private var showFromPicker = false
    @State private var showToPicker = false
    @State private var showFavorites = false
    @State private var showSettings = false

    private var amount: Double { Double(amountText) ?? 0 }
    private var currentPair: CurrencyPair { CurrencyPair(from: from.code, to: to.code) }
    private var refreshKey: String { "\(from.code)-\(to.code)" }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .frame(height: 76)

                    amountDisplay
                        .frame(height: 108)

                    currencyRow
                        .frame(height: 88)
                        .padding(.horizontal, 18)

                    keypad
                        .frame(maxHeight: .infinity)

                    footer
                        .frame(height: 64)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .sheet(isPresented: $showFromPicker) {
            CurrencyPickerView(title: "Starting Currency", selection: $from)
        }
        .sheet(isPresented: $showToPicker) {
            CurrencyPickerView(title: "Ending Currency", selection: $to)
        }
        .sheet(isPresented: $showFavorites) {
            FavoritesView(currentPair: currentPair) { pair in
                from = CurrencyCatalog.currency(pair.from)
                to = CurrencyCatalog.currency(pair.to)
            }
            .environmentObject(rates)
            .environmentObject(favorites)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .task(id: refreshKey) {
            while !Task.isCancelled {
                await rates.refresh(codes: [from.code, to.code])
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    private var header: some View {
        ZStack {
            HStack {
                CircleIconButton(
                    systemName: favorites.contains(currentPair) ? "star.fill" : "star",
                    accent: favorites.contains(currentPair) ? .yellow : .white
                ) {
                    showFavorites = true
                }
                Spacer()
            }
            .padding(.horizontal, 18)

            Text(headerRateText)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .padding(.horizontal, 78)
        }
        .background(Color.black)
    }

    private var amountDisplay: some View {
        HStack(spacing: 22) {
            Text(displayInput)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text("=")
                .foregroundStyle(.white.opacity(0.18))
                .font(.system(size: 56, weight: .ultraLight, design: .rounded))

            Text(displayOutput)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 56, weight: .ultraLight, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.40)
        .padding(.horizontal, 24)
        .background(Color.black)
    }

    private var currencyRow: some View {
        HStack(spacing: 8) {
            CurrencyButton(currency: from) { showFromPicker = true }

            Image(systemName: "arrow.right")
                .font(.system(size: 29, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.70))
                .frame(width: 36)

            CurrencyButton(currency: to) { showToPicker = true }
        }
        .background(Color.black)
    }

    private var keypad: some View {
        GeometryReader { geo in
            let divider: CGFloat = 1
            let actionWidth = geo.size.width * 0.25
            let leftWidth = geo.size.width - actionWidth - divider
            let keyWidth = (leftWidth - (divider * 2)) / 3
            let rowHeight = (geo.size.height - (divider * 3)) / 4

            HStack(spacing: divider) {
                VStack(spacing: divider) {
                    HStack(spacing: divider) {
                        KeyButton("7", width: keyWidth, height: rowHeight) { append("7") }
                        KeyButton("8", width: keyWidth, height: rowHeight) { append("8") }
                        KeyButton("9", width: keyWidth, height: rowHeight) { append("9") }
                    }
                    HStack(spacing: divider) {
                        KeyButton("4", width: keyWidth, height: rowHeight) { append("4") }
                        KeyButton("5", width: keyWidth, height: rowHeight) { append("5") }
                        KeyButton("6", width: keyWidth, height: rowHeight) { append("6") }
                    }
                    HStack(spacing: divider) {
                        KeyButton("1", width: keyWidth, height: rowHeight) { append("1") }
                        KeyButton("2", width: keyWidth, height: rowHeight) { append("2") }
                        KeyButton("3", width: keyWidth, height: rowHeight) { append("3") }
                    }
                    HStack(spacing: divider) {
                        KeyButton(".", width: keyWidth, height: rowHeight) { appendDecimal() }
                        KeyButton("0", width: keyWidth * 2 + divider, height: rowHeight) { append("0") }
                    }
                }
                .frame(width: leftWidth)

                VStack(spacing: divider) {
                    ActionKey(
                        background: Color(red: 1.00, green: 0.20, blue: 0.20),
                        foreground: .white,
                        systemName: "trash",
                        height: rowHeight
                    ) {
                        amountText = ""
                    }

                    ActionKey(
                        background: Color(white: 0.96),
                        foreground: .black,
                        systemName: "delete.left",
                        height: rowHeight
                    ) {
                        backspace()
                    }

                    Button {
                        let previous = from
                        from = to
                        to = previous
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 27, weight: .light))
                            Text("Switch")
                                .font(.system(size: 18, weight: .regular, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(red: 0.20, green: 0.84, blue: 0.31))
                    }
                    .buttonStyle(.plain)
                    .frame(height: rowHeight * 2 + divider)
                }
                .frame(width: actionWidth)
            }
            .background(Color.white.opacity(0.18))
        }
    }

    private var footer: some View {
        HStack {
            Text("Last Updated: \(updatedTime)")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.90))

            Spacer()

            Button("Settings") {
                showSettings = true
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(red: 0.10, green: 0.58, blue: 1.0))
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.10))
    }

    private var headerRateText: String {
        guard let value = rates.rate(from: from.code, to: to.code) else {
            return "1 \(from.code) = — \(to.code)"
        }
        return "1 \(from.code) = \(format(value, decimals: 3)) \(to.code)"
    }

    private var displayInput: String {
        amountText.isEmpty ? "0" : amountText
    }

    private var displayOutput: String {
        guard let value = rates.convert(amount, from: from.code, to: to.code) else { return "—" }
        return format(value, decimals: 0)
    }

    private var updatedTime: String {
        guard let date = rates.updatedAt else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func format(_ value: Double, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func append(_ character: String) {
        guard amountText.count < 16 else { return }
        if amountText == "0" { amountText = character }
        else { amountText.append(character) }
    }

    private func appendDecimal() {
        guard !amountText.contains(".") else { return }
        if amountText.isEmpty { amountText = "0." }
        else { amountText.append(".") }
    }

    private func backspace() {
        guard !amountText.isEmpty else { return }
        amountText.removeLast()
    }
}

private struct CircleIconButton: View {
    let systemName: String
    var accent: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 54, height: 54)
                .background(Circle().fill(Color.white.opacity(0.10)))
                .overlay(Circle().stroke(Color.white.opacity(0.11), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct CurrencyButton: View {
    let currency: CurrencyInfo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(currency.flag)
                    .font(.system(size: 34))

                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.code)
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Tap to change")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct KeyButton: View {
    let title: String
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 34, weight: .light, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: width, height: height)
                .background(Color.black)
        }
        .buttonStyle(.plain)
    }
}

private struct ActionKey: View {
    let background: Color
    let foreground: Color
    let systemName: String
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(background)
        }
        .buttonStyle(.plain)
        .frame(height: height)
    }
}

struct CurrencyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var selection: CurrencyInfo
    @State private var search = ""

    private var filtered: [CurrencyInfo] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return CurrencyCatalog.all }
        return CurrencyCatalog.all.filter {
            $0.code.localizedCaseInsensitiveContains(query) ||
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { currency in
                Button {
                    selection = currency
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Text(currency.flag)
                            .font(.system(size: 30))
                            .frame(width: 42)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(currency.name)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(currency.code)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if selection.code == currency.code {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.black)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .searchable(text: $search, prompt: "Search for currency…")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "checkmark") }
                }
            }
        }
        .presentationBackground(Color.black)
    }
}

struct FavoritesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var rates: RateService
    @EnvironmentObject private var favorites: FavoritesStore

    let currentPair: CurrencyPair
    let onSelect: (CurrencyPair) -> Void

    @State private var showAddCurrency = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.075).ignoresSafeArea()

                if favorites.pairs.isEmpty {
                    VStack(spacing: 13) {
                        Image(systemName: "star")
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("No Favorites")
                            .font(.title3.weight(.semibold))
                        Text("Tap + and choose a currency.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        ForEach(favorites.pairs) { pair in
                            HStack(spacing: 6) {
                                Button {
                                    onSelect(pair)
                                    dismiss()
                                } label: {
                                    FavoriteRow(pair: pair)
                                        .environmentObject(rates)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Button(role: .destructive) {
                                    favorites.remove(pair)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(.red)
                                        .frame(width: 40, height: 40)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 3)
                            .listRowBackground(Color(white: 0.075))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    favorites.remove(pair)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: favorites.remove)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddCurrency = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 19, weight: .bold))
                    }
                }
            }
        }
        .presentationBackground(Color(white: 0.075))
        .sheet(isPresented: $showAddCurrency) {
            FavoriteCurrencyAddList(baseCode: currentPair.from)
                .environmentObject(favorites)
                .environmentObject(rates)
        }
        .task {
            await refreshFavoriteRates()
        }
        .onChange(of: favorites.pairs) { _ in
            Task { await refreshFavoriteRates() }
        }
    }

    private func refreshFavoriteRates() async {
        let codes = Set(favorites.pairs.flatMap { [$0.from, $0.to] })
        guard !codes.isEmpty else { return }
        await rates.refresh(codes: codes)
    }
}

private struct FavoriteCurrencyAddList: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var rates: RateService

    let baseCode: String
    @State private var search = ""

    private var filtered: [CurrencyInfo] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = CurrencyCatalog.all.filter { $0.code != baseCode }
        if query.isEmpty { return all }
        return all.filter {
            $0.code.localizedCaseInsensitiveContains(query) ||
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { currency in
                let pair = CurrencyPair(from: baseCode, to: currency.code)
                Button {
                    if favorites.contains(pair) {
                        favorites.remove(pair)
                    } else {
                        favorites.add(pair)
                        Task { await rates.refresh(codes: [baseCode, currency.code]) }
                    }
                } label: {
                    HStack(spacing: 14) {
                        Text(currency.flag)
                            .font(.system(size: 30))
                            .frame(width: 42)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(currency.name)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(currency.code)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: favorites.contains(pair) ? "checkmark.circle.fill" : "plus.circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(favorites.contains(pair) ? .green : .blue)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.black)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .searchable(text: $search, prompt: "Search currency…")
            .navigationTitle("Add Favorite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .presentationBackground(Color.black)
    }
}

private struct FavoriteRow: View {
    @EnvironmentObject private var rates: RateService
    let pair: CurrencyPair

    var body: some View {
        HStack(spacing: 14) {
            Text(CurrencyCatalog.flag(for: pair.to))
                .font(.system(size: 31))
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(rateText)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(pair.to) (\(CurrencyCatalog.currency(pair.to).name))")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 7)
    }

    private var rateText: String {
        guard let rate = rates.rate(from: pair.from, to: pair.to) else {
            return "1 \(pair.from) → — \(pair.to)"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = rate >= 100 ? 0 : 3
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        let value = formatter.string(from: NSNumber(value: rate)) ?? "—"
        return "1 \(pair.from) → \(value) \(pair.to)"
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var certificateExpiration = MXCertificateInfo.expirationDate()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.075).ignoresSafeArea()

                VStack(spacing: 0) {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        let status = renewalStatus(now: context.date)

                        Button {
                            openSideStore()
                        } label: {
                            HStack(spacing: 13) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.18))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(.green)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Renew App")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("Tap to open SideStore to renew")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 8)

                                Text(status.text)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(status.expired ? .red : .green)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill((status.expired ? Color.red : Color.green).opacity(0.15))
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke((status.expired ? Color.red : Color.green).opacity(0.35), lineWidth: 1)
                                    )

                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.07))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 18)
                        .padding(.top, 26)
                    }

                    Spacer()

                    VStack(spacing: 6) {
                        Text("MX")
                            .font(.system(size: 25, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                        Text("MazenmiX")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 44)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
            }
        }
        .presentationBackground(Color(white: 0.075))
        .onAppear {
            certificateExpiration = MXCertificateInfo.expirationDate()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                certificateExpiration = MXCertificateInfo.expirationDate()
            }
        }
    }

    private func openSideStore() {
        guard let url = URL(string: "sidestore://") else { return }
        UIApplication.shared.open(url)
    }

    private func renewalStatus(now: Date) -> (text: String, expired: Bool) {
        guard let expiration = certificateExpiration else {
            return ("—", false)
        }

        let remaining = expiration.timeIntervalSince(now)
        if remaining <= 0 {
            return ("Expired", true)
        }

        let totalHours = max(0, Int(remaining / 3600))
        let days = totalHours / 24
        let hours = totalHours % 24

        if days > 0 {
            return ("\(days)d \(hours)h left", false)
        }
        return ("\(hours)h left", false)
    }
}
