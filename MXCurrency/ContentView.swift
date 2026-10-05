import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var rates: RateService
    @EnvironmentObject private var favorites: FavoritesStore
    @AppStorage("decimalPoints") private var decimalPoints = 0

    @State private var from = CurrencyCatalog.currency("USD")
    @State private var to = CurrencyCatalog.currency("PHP")
    @State private var amountText = ""
    @State private var showFromPicker = false
    @State private var showToPicker = false
    @State private var showFavorites = false
    @State private var showLiveRates = false
    @State private var showSettings = false

    private var amount: Double { Double(amountText) ?? 0 }
    private var currentPair: CurrencyPair { CurrencyPair(from: from.code, to: to.code) }
    private var refreshKey: String { "\(from.code)-\(to.code)" }

    var body: some View {
        GeometryReader { geometry in
            let keypadHeight = max(390, geometry.size.height * 0.54)

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 28)
                        .padding(.top, 10)

                    amountDisplay
                        .padding(.top, 34)

                    currencyRow
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                        .padding(.bottom, 20)

                    keypad
                        .frame(height: keypadHeight)

                    footer
                        .padding(.horizontal, 20)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 12)
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
        .sheet(isPresented: $showLiveRates) {
            LiveRatesView()
                .environmentObject(rates)
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
        HStack {
            CircleIconButton(systemName: favorites.contains(currentPair) ? "star.fill" : "star", accent: favorites.contains(currentPair) ? .yellow : .white) {
                showFavorites = true
            }

            Spacer()

            VStack(spacing: 4) {
                Text(headerRateText)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 5) {
                    Circle()
                        .fill(rates.pairKind(from: from.code, to: to.code) == "Parallel Market" ? Color.orange : Color.green)
                        .frame(width: 6, height: 6)
                    Text(rates.pairKind(from: from.code, to: to.code))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            CircleIconButton(systemName: "chart.bar.xaxis") {
                showLiveRates = true
            }
        }
    }

    private var amountDisplay: some View {
        HStack(spacing: 26) {
            Text(displayInput)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text("=")
                .foregroundStyle(.white.opacity(0.24))
                .font(.system(size: 58, weight: .ultraLight, design: .rounded))

            Text(displayOutput)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 58, weight: .ultraLight, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.45)
        .padding(.horizontal, 24)
    }

    private var currencyRow: some View {
        HStack(spacing: 10) {
            CurrencyButton(currency: from) { showFromPicker = true }

            Image(systemName: "arrow.right")
                .font(.system(size: 30, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 34)

            CurrencyButton(currency: to) { showToPicker = true }
        }
    }

    private var keypad: some View {
        HStack(spacing: 1) {
            VStack(spacing: 1) {
                HStack(spacing: 1) {
                    KeyButton("7") { append("7") }
                    KeyButton("8") { append("8") }
                    KeyButton("9") { append("9") }
                }
                HStack(spacing: 1) {
                    KeyButton("4") { append("4") }
                    KeyButton("5") { append("5") }
                    KeyButton("6") { append("6") }
                }
                HStack(spacing: 1) {
                    KeyButton("1") { append("1") }
                    KeyButton("2") { append("2") }
                    KeyButton("3") { append("3") }
                }
                HStack(spacing: 1) {
                    KeyButton(".") { appendDecimal() }
                    KeyButton("0", widthWeight: 2) { append("0") }
                }
            }

            VStack(spacing: 1) {
                ActionKey(background: Color(red: 1.0, green: 0.20, blue: 0.20), foreground: .white, systemName: "trash") {
                    amountText = ""
                }
                ActionKey(background: .white.opacity(0.94), foreground: .black, systemName: "delete.left") {
                    backspace()
                }
                Button {
                    let old = from
                    from = to
                    to = old
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 27, weight: .light))
                        Text("Switch")
                            .font(.system(size: 18, weight: .regular, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.19, green: 0.84, blue: 0.31))
                }
                .buttonStyle(.plain)
            }
            .frame(width: 112)
        }
        .background(Color.white.opacity(0.16))
    }

    private var footer: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(rates.isRefreshing ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    Text(rates.isRefreshing ? "Updating" : "Live")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(rates.isRefreshing ? .orange : .green)
                }

                Text("Last Updated: \(updatedTime)")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))

                if let source = rates.pairSource(from: from.code, to: to.code) {
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                    Text("Settings")
                        .font(.caption)
                }
                .foregroundStyle(Color(red: 0.10, green: 0.58, blue: 1.0))
            }
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
        if amountText.isEmpty { return "0" }
        return amountText
    }

    private var displayOutput: String {
        guard let value = rates.convert(amount, from: from.code, to: to.code) else { return "—" }
        return format(value, decimals: decimalPoints)
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
                .font(.system(size: 24, weight: .medium))
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
    var widthWeight: CGFloat = 1
    let action: () -> Void

    init(_ title: String, widthWeight: CGFloat = 1, action: @escaping () -> Void) {
        self.title = title
        self.widthWeight = widthWeight
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 34, weight: .light, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
        .buttonStyle(.plain)
        .layoutPriority(widthWeight)
    }
}

private struct ActionKey: View {
    let background: Color
    let foreground: Color
    let systemName: String
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
    }
}

struct CurrencyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var selection: CurrencyInfo
    @State private var search = ""

    private var filtered: [CurrencyInfo] {
        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return CurrencyCatalog.all }
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
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .topBarTrailing) {
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
    @AppStorage("decimalPoints") private var decimalPoints = 0

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
                        FavoriteRow(pair: pair, decimals: max(3, decimalPoints))
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
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .topBarTrailing) {
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
    let decimals: Int

    var body: some View {
        HStack(spacing: 14) {
            Text(CurrencyCatalog.flag(for: pair.to))
                .font(.system(size: 31))
                .frame(width: 42)

            VStack(alignment: .leading, spacing: 2) {
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
        formatter.maximumFractionDigits = decimals
        formatter.minimumFractionDigits = 0
        let value = formatter.string(from: NSNumber(value: rate)) ?? "—"
        return "1 \(pair.from) → \(value) \(pair.to)"
    }
}

struct LiveRatesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var rates: RateService
    @State private var search = ""

    private var currencies: [CurrencyInfo] {
        let base = CurrencyCatalog.all.filter { $0.code != "USD" && rates.rates[$0.code] != nil }
        if search.isEmpty { return Array(base.prefix(60)) }
        return base.filter {
            $0.code.localizedCaseInsensitiveContains(search) || $0.name.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List(currencies) { currency in
                HStack(spacing: 14) {
                    Text(currency.flag)
                        .font(.system(size: 28))
                        .frame(width: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currency.code)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                        Text(currency.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(value(currency.code))
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                        Text(rates.meta[currency.code]?.kind == "parallel" ? "PARALLEL" : "MARKET")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(rates.meta[currency.code]?.kind == "parallel" ? .orange : .green)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.black)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .searchable(text: $search, prompt: "Search currency…")
            .navigationTitle("Live Rates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if rates.isRefreshing { ProgressView() }
                    else {
                        Button {
                            Task { await refreshVisible() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .presentationBackground(Color.black)
        .task { await refreshVisible() }
    }

    private func value(_ code: String) -> String {
        guard let number = rates.rates[code] else { return "—" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = number >= 100 ? 2 : 4
        return formatter.string(from: NSNumber(value: number)) ?? "—"
    }

    private func refreshVisible() async {
        let codes = Set(CurrencyCatalog.priority.prefix(20))
        await rates.refresh(codes: codes)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("decimalPoints") private var decimalPoints = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.09).ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("General")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 18)

                        Menu {
                            Picker("Decimal Points", selection: $decimalPoints) {
                                ForEach(0...6, id: \.self) { number in
                                    Text("\(number)").tag(number)
                                }
                            }
                        } label: {
                            HStack {
                                Text("Decimal Points")
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(decimalPoints)")
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary.opacity(0.65))
                            }
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .padding(.horizontal, 18)
                            .frame(height: 62)
                            .background(Color.white.opacity(0.08))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 34)

                    Spacer()

                    VStack(spacing: 12) {
                        MXBrandMark()
                            .frame(width: 118, height: 78)
                        Text("MazenmiX")
                            .font(.system(size: 19, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.bottom, 70)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .presentationBackground(Color.black)
    }
}

private struct MXBrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))

            HStack(spacing: -8) {
                Text("M")
                    .foregroundStyle(.white)
                Text("X")
                    .foregroundStyle(Color.orange)
            }
            .font(.system(size: 48, weight: .black, design: .rounded))
            .italic()
        }
    }
}
