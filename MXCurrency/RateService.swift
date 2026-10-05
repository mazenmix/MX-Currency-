import SwiftUI

@MainActor
final class RateService: ObservableObject {
    @Published private(set) var rates: [String: Double] = ["USD": 1]
    @Published private(set) var meta: [String: RateMeta] = [:]
    @Published private(set) var updatedAt: Date?
    @Published private(set) var isRefreshing = false

    private var lastBaseRefresh: Date?

    private let remoteBookURL = URL(string: "https://raw.githubusercontent.com/mazenmix/MX-Currency-/main/data/rates.json")!
    private let fallbackURL = URL(string: "https://open.er-api.com/v6/latest/USD")!

    func rate(from: String, to: String) -> Double? {
        guard let fromRate = rates[from], let toRate = rates[to], fromRate > 0 else { return nil }
        return toRate / fromRate
    }

    func convert(_ amount: Double, from: String, to: String) -> Double? {
        guard let pairRate = rate(from: from, to: to) else { return nil }
        return amount * pairRate
    }

    func pairKind(from: String, to: String) -> String {
        if meta[from]?.kind == "parallel" || meta[to]?.kind == "parallel" {
            return "Parallel Market"
        }
        if meta[from]?.kind == "live-market" || meta[to]?.kind == "live-market" {
            return "Live Market"
        }
        return "Market"
    }

    func pairSource(from: String, to: String) -> String? {
        if let item = meta[to], item.kind == "parallel" { return item.source }
        if let item = meta[from], item.kind == "parallel" { return item.source }
        if let item = meta[to], item.kind == "live-market" { return item.source }
        if let item = meta[from], item.kind == "live-market" { return item.source }
        return nil
    }

    func refresh(codes: Set<String>) async {
        if isRefreshing { return }
        isRefreshing = true
        defer { isRefreshing = false }

        if lastBaseRefresh == nil || Date().timeIntervalSince(lastBaseRefresh!) > 900 {
            await loadBaseRates()
            lastBaseRefresh = Date()
        }

        let liveCodes = codes
            .filter { $0 != "USD" && $0 != "IQD" && $0 != "ARS" }
            .prefix(20)

        let liveResults = await withTaskGroup(of: (String, Double?).self, returning: [(String, Double?)].self) { group in
            for code in liveCodes {
                group.addTask {
                    (code, await Self.fetchYahooRate(code: code))
                }
            }
            var output: [(String, Double?)] = []
            for await result in group { output.append(result) }
            return output
        }

        for (code, value) in liveResults {
            if let value, value > 0 {
                rates[code] = value
                meta[code] = RateMeta(
                    kind: "live-market",
                    source: "Yahoo Finance FX",
                    buy: nil,
                    sell: nil,
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                )
            }
        }

        if codes.contains("IQD"), let quote = await Self.fetchIraqParallel() {
            rates["IQD"] = quote.mid
            meta["IQD"] = RateMeta(
                kind: "parallel",
                source: "Baghdad street · @dollariraqi",
                buy: quote.buy,
                sell: quote.sell,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
        }

        if codes.contains("ARS"), let quote = await Self.fetchArgentinaBlue() {
            rates["ARS"] = quote.mid
            meta["ARS"] = RateMeta(
                kind: "parallel",
                source: "Argentina Blue · DolarApi",
                buy: quote.buy,
                sell: quote.sell,
                updatedAt: quote.updatedAt
            )
        }

        updatedAt = Date()
    }

    private func loadBaseRates() async {
        if let data = try? await Self.fetchData(from: remoteBookURL),
           let book = try? JSONDecoder().decode(RateBook.self, from: data),
           book.base == "USD" {
            rates.merge(book.rates) { _, new in new }
            if let incomingMeta = book.meta {
                meta.merge(incomingMeta) { _, new in new }
            }
            if let date = ISO8601DateFormatter().date(from: book.updatedAt) {
                updatedAt = date
            }
            return
        }

        if let data = try? await Self.fetchData(from: fallbackURL),
           let response = try? JSONDecoder().decode(OpenERResponse.self, from: data),
           response.result == "success" {
            rates.merge(response.rates) { _, new in new }
            updatedAt = Date()
        }
    }

    nonisolated private static func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    nonisolated private static func fetchYahooRate(code: String) async -> Double? {
        guard code != "USD",
              let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/USD\(code)=X?interval=1m&range=1d") else { return nil }
        do {
            let data = try await fetchData(from: url)
            let response = try JSONDecoder().decode(YahooChartResponse.self, from: data)
            guard let meta = response.chart.result?.first?.meta else { return nil }
            return meta.regularMarketPrice ?? meta.previousClose
        } catch {
            return nil
        }
    }

    nonisolated private static func fetchArgentinaBlue() async -> (buy: Double, sell: Double, mid: Double, updatedAt: String?)? {
        guard let url = URL(string: "https://dolarapi.com/v1/dolares/blue") else { return nil }
        do {
            let data = try await fetchData(from: url)
            let quote = try JSONDecoder().decode(ArgentinaBlueQuote.self, from: data)
            guard quote.compra > 0, quote.venta > 0 else { return nil }
            return (quote.compra, quote.venta, (quote.compra + quote.venta) / 2, quote.fechaActualizacion)
        } catch {
            return nil
        }
    }

    nonisolated private static func fetchIraqParallel() async -> (buy: Double, sell: Double, mid: Double)? {
        guard let url = URL(string: "https://t.me/s/dollariraqi") else { return nil }
        do {
            let data = try await fetchData(from: url)
            guard var html = String(data: data, encoding: .utf8) else { return nil }
            html = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            html = html.replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&amp;", with: "&")

            if let direct = lastRegexMatch(
                pattern: #"بغداد\s*-\s*صيرفات\s*:\s*([0-9,.]+)\s*بيع\s*-\s*([0-9,.]+)\s*شراء"#,
                in: html
            ), direct.count >= 3,
               let sell = iraqCashPerDollar(direct[1]),
               let buy = iraqCashPerDollar(direct[2]) {
                return (buy, sell, (buy + sell) / 2)
            }

            if let board = lastRegexMatch(
                pattern: #"(?:كفاح|حارثية)\s*([0-9,.]+)\s*\|\s*([0-9,.]+)"#,
                in: html
            ), board.count >= 3,
               let buy = iraqBoardPerDollar(board[1]),
               let sell = iraqBoardPerDollar(board[2]) {
                return (buy, sell, (buy + sell) / 2)
            }
        } catch {
            return nil
        }
        return nil
    }

    nonisolated private static func lastRegexMatch(pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.matches(in: text, range: nsRange).last else { return nil }
        return (0..<match.numberOfRanges).compactMap { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
            return String(text[swiftRange])
        }
    }

    nonisolated private static func iraqCashPerDollar(_ raw: String) -> Double? {
        let digits = raw.filter(\.isNumber)
        guard let value = Double(digits), value >= 100_000 else { return nil }
        return value / 100
    }

    nonisolated private static func iraqBoardPerDollar(_ raw: String) -> Double? {
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        let pieces = normalized.split(separator: ".")
        if pieces.count == 2,
           let whole = Double(pieces[0]),
           pieces[0].count == 3,
           pieces[1].count == 3,
           let combined = Double(String(pieces[0]) + String(pieces[1])) {
            return combined / 100
        }
        if let value = Double(normalized), value >= 1000 { return value }
        return nil
    }
}
