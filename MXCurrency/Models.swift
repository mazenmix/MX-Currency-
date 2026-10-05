import Foundation

struct CurrencyInfo: Identifiable, Hashable {
    let code: String
    let name: String
    let flag: String

    var id: String { code }
}

struct CurrencyPair: Codable, Hashable, Identifiable {
    let from: String
    let to: String

    var id: String { "\(from)-\(to)" }
}

struct RateBook: Codable {
    let base: String
    let updatedAt: String
    let rates: [String: Double]
    let meta: [String: RateMeta]?
}

struct RateMeta: Codable, Hashable {
    let kind: String
    let source: String
    let buy: Double?
    let sell: Double?
    let updatedAt: String?
}

struct OpenERResponse: Decodable {
    let result: String
    let time_last_update_utc: String?
    let rates: [String: Double]
}

struct ArgentinaBlueQuote: Decodable {
    let compra: Double
    let venta: Double
    let fechaActualizacion: String?
}

struct YahooChartResponse: Decodable {
    struct Chart: Decodable {
        struct Result: Decodable {
            struct Meta: Decodable {
                let regularMarketPrice: Double?
                let previousClose: Double?
            }
            let meta: Meta
        }
        let result: [Result]?
    }
    let chart: Chart
}
