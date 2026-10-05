import Foundation

struct CurrencyCatalog {
    static let priority = [
        "USD", "EUR", "GBP", "IQD", "PHP", "IDR", "TRY", "THB", "VND", "AED", "SAR", "QAR", "KWD",
        "MYR", "SGD", "JPY", "CNY", "HKD", "KRW", "INR", "AUD", "NZD", "CAD", "CHF", "ARS", "BRL", "MXN"
    ]

    static let all: [CurrencyInfo] = {
        let codes = Set(Locale.commonISOCurrencyCodes)
        let items = codes.map { code in
            CurrencyInfo(
                code: code,
                name: Locale.current.localizedString(forCurrencyCode: code) ?? code,
                flag: flag(for: code)
            )
        }

        return items.sorted { a, b in
            let ai = priority.firstIndex(of: a.code)
            let bi = priority.firstIndex(of: b.code)
            switch (ai, bi) {
            case let (.some(x), .some(y)): return x < y
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }
    }()

    static func currency(_ code: String) -> CurrencyInfo {
        all.first(where: { $0.code == code }) ?? CurrencyInfo(code: code, name: code, flag: flag(for: code))
    }

    static func flag(for code: String) -> String {
        flagMap[code] ?? "🌐"
    }

    private static let flagMap: [String: String] = [
        "USD":"🇺🇸", "EUR":"🇪🇺", "GBP":"🇬🇧", "IQD":"🇮🇶", "PHP":"🇵🇭", "IDR":"🇮🇩", "TRY":"🇹🇷",
        "THB":"🇹🇭", "VND":"🇻🇳", "AED":"🇦🇪", "SAR":"🇸🇦", "QAR":"🇶🇦", "KWD":"🇰🇼", "BHD":"🇧🇭",
        "OMR":"🇴🇲", "JOD":"🇯🇴", "LBP":"🇱🇧", "SYP":"🇸🇾", "IRR":"🇮🇷", "ILS":"🇮🇱", "EGP":"🇪🇬",
        "MAD":"🇲🇦", "DZD":"🇩🇿", "TND":"🇹🇳", "LYD":"🇱🇾", "SDG":"🇸🇩", "MYR":"🇲🇾", "SGD":"🇸🇬",
        "BND":"🇧🇳", "JPY":"🇯🇵", "CNY":"🇨🇳", "HKD":"🇭🇰", "MOP":"🇲🇴", "KRW":"🇰🇷", "TWD":"🇹🇼",
        "INR":"🇮🇳", "PKR":"🇵🇰", "BDT":"🇧🇩", "LKR":"🇱🇰", "NPR":"🇳🇵", "AFN":"🇦🇫", "MMK":"🇲🇲",
        "KHR":"🇰🇭", "LAK":"🇱🇦", "MNT":"🇲🇳", "KZT":"🇰🇿", "UZS":"🇺🇿", "GEL":"🇬🇪", "AMD":"🇦🇲",
        "AZN":"🇦🇿", "RUB":"🇷🇺", "UAH":"🇺🇦", "PLN":"🇵🇱", "CZK":"🇨🇿", "HUF":"🇭🇺", "RON":"🇷🇴",
        "BGN":"🇧🇬", "RSD":"🇷🇸", "ALL":"🇦🇱", "MKD":"🇲🇰", "BAM":"🇧🇦", "MDL":"🇲🇩", "BYN":"🇧🇾",
        "CHF":"🇨🇭", "SEK":"🇸🇪", "NOK":"🇳🇴", "DKK":"🇩🇰", "ISK":"🇮🇸", "AUD":"🇦🇺", "NZD":"🇳🇿",
        "CAD":"🇨🇦", "MXN":"🇲🇽", "BRL":"🇧🇷", "ARS":"🇦🇷", "CLP":"🇨🇱", "COP":"🇨🇴", "PEN":"🇵🇪",
        "UYU":"🇺🇾", "PYG":"🇵🇾", "BOB":"🇧🇴", "VES":"🇻🇪", "GYD":"🇬🇾", "SRD":"🇸🇷", "ZAR":"🇿🇦",
        "NGN":"🇳🇬", "GHS":"🇬🇭", "KES":"🇰🇪", "TZS":"🇹🇿", "UGX":"🇺🇬", "ETB":"🇪🇹", "RWF":"🇷🇼",
        "ZMW":"🇿🇲", "BWP":"🇧🇼", "MUR":"🇲🇺", "MGA":"🇲🇬", "XOF":"🌍", "XAF":"🌍", "XPF":"🌏"
    ]
}
