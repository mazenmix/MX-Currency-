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
        GeometryReader { geometry in
            let keypadHeight = min(max(420, geometry.size.height * 0.54), 520)

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 18)
                        .padding(.top, 12)

                    amountDisplay
                        .padding(.top, 34)

                    currencyRow
                        .padding(.horizontal, 18)
                        .padding(.top, 28)
                        .padding(.bottom, 20)

                    keypad
                        .frame(height: keypadHeight)

                    footer
                        .padding(.horizontal, 20)
                        .padding(.top, 13)
                        .padding(.bottom, 8)
                }
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

            Text(headerRateText)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 76)
        }
        .frame(height: 56)
    }

    private var amountDisplay: some View {
        HStack(spacing: 22) {
            Text(displayInput)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text("=")
                .foregroundStyle(.white.opacity(0.18))
                .font(.system(size: 58, weight: .ultraLight, design: .rounded))

            Text(displayOutput)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 58, weight: .ultraLight, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.42)
        .padding(.horizontal, 28)
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
                .foregroundStyle(.white.opacity(0.88))

            Spacer()

            Button("Settings") {
                showSettings = true
            }
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(red: 0.10, green: 0.58, blue: 1.0))
            .buttonStyle(.plain)
        }
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
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
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

    init(_ title: String, width: CGFloat, height: CGFloat, action: @escaping () -> Void) {
        self.title = title
        self.width = width
        self.height = height
        self.action = action
    }

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
        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return CurrencyCatalog.all
        }
        return CurrencyCatalog.all.filter {
            $0.code.localizedCaseInsensitiveContains(search) ||
            $0.name.localizedCaseInsensitiveContains(search)
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

    var body: some View {
        NavigationStack {
            List {
                ForEach(favorites.pairs) { pair in
                    Button {
                        onSelect(pair)
                        dismiss()
                    } label: {
                        FavoriteRow(pair: pair)
                            .environmentObject(rates)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.black)
                }
                .onDelete(perform: favorites.remove)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        favorites.add(currentPair)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(favorites.contains(currentPair))
                }
            }
        }
        .presentationBackground(Color.black)
        .task {
            let codes = Set(favorites.pairs.flatMap { [$0.from, $0.to] })
            await rates.refresh(codes: codes)
        }
    }
}

private struct FavoriteRow: View {
    @EnvironmentObject private var rates: RateService
    let pair: CurrencyPair

    var body: some View {
        HStack(spacing: 14) {
            Text(CurrencyCatalog.flag(for: pair.to))
                .font(.system(size: 31))
                .frame(width: 42)

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
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        let value = formatter.string(from: NSNumber(value: rate)) ?? "—"
        return "1 \(pair.from) → \(value) \(pair.to)"
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var certificateExpiration = MXCertificateInfo.expirationDate()
    @State private var showSideStoreError = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.085, green: 0.085, blue: 0.095).ignoresSafeArea()

                VStack(spacing: 0) {
                    renewalCard
                        .padding(.horizontal, 18)
                        .padding(.top, 28)

                    Spacer()

                    VStack(spacing: 7) {
                        Text("MX")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.13))
                            .italic()
                        Text("MazenmiX")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 54)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(Color.white.opacity(0.10)))
                    }
                }
            }
        }
        .presentationBackground(Color.black)
        .onAppear {
            certificateExpiration = MXCertificateInfo.expirationDate()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                certificateExpiration = MXCertificateInfo.expirationDate()
            }
        }
        .alert("SideStore", isPresented: $showSideStoreError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("SideStore could not be opened. Make sure SideStore is installed.")
        }
    }

    private var renewalCard: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let state = renewalState(now: context.date)

            Button {
                openSideStore()
            } label: {
                HStack(spacing: 13) {
                    ZStack {
                        Circle()
                            .fill((state.expired ? Color.red : Color.green).opacity(0.18))
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(state.expired ? Color.red : Color.green)
                    }
                    .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Renew App")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(state.subtitle)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(state.remaining)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(state.expired ? Color.red : Color.green)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill((state.expired ? Color.red : Color.green).opacity(0.15))
                        )
                        .overlay(
                            Capsule()
                                .stroke((state.expired ? Color.red : Color.green).opacity(0.55), lineWidth: 1)
                        )

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .fill(Color.white.opacity(0.075))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(Color.white.opacity(0.075), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func renewalState(now: Date) -> RenewalState {
        guard let expiration = certificateExpiration else {
            return RenewalState(
                remaining: "—",
                subtitle: "Tap to open SideStore to renew",
                expired: false
            )
        }

        let seconds = expiration.timeIntervalSince(now)
        guard seconds > 0 else {
            return RenewalState(
                remaining: "Expired",
                subtitle: "Tap to open SideStore to renew",
                expired: true
            )
        }

        let totalHours = max(0, Int(seconds / 3600))
        let days = totalHours / 24
        let hours = totalHours % 24
        let remaining = days > 0 ? "\(days)d \(hours)h" : "\(hours)h"

        return RenewalState(
            remaining: remaining,
            subtitle: "Tap to open SideStore to renew",
            expired: false
        )
    }

    private func openSideStore() {
        guard let url = URL(string: "sidestore://") else { return }
        UIApplication.shared.open(url, options: [:]) { opened in
            if !opened {
                DispatchQueue.main.async {
                    showSideStoreError = true
                }
            }
        }
    }
}

private struct RenewalState {
    let remaining: String
    let subtitle: String
    let expired: Bool
}
