from pathlib import Path
import re

path = Path("MXCurrency/ContentView.swift")
s = path.read_text(encoding="utf-8")

# Keep the proportions close to the user's reference: compact header,
# balanced amount area, and a clean currency row.
s = s.replace('header\n                        .frame(height: 76)', 'header\n                        .frame(height: 82)')
s = s.replace('header\n                        .frame(height: 88)', 'header\n                        .frame(height: 82)')
s = s.replace('amountDisplay\n                        .frame(height: 108)', 'amountDisplay\n                        .frame(height: 112)')
s = s.replace('currencyRow\n                        .frame(height: 88)', 'currencyRow\n                        .frame(height: 86)')

header_pattern = re.compile(r'    private var header: some View \{.*?\n    \}\n\n    private var amountDisplay:', re.S)
header_replacement = '''    private var header: some View {
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
            .padding(.horizontal, 29)

            Text(headerRateText)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
                .padding(.horizontal, 88)
        }
        .background(Color.black)
    }

    private var amountDisplay:'''
s, count = header_pattern.subn(header_replacement, s, count=1)
if count != 1:
    raise SystemExit("Could not patch header layout")

amount_pattern = re.compile(r'    private var amountDisplay: some View \{.*?\n    \}\n\n    private var currencyRow:', re.S)
amount_replacement = '''    private var amountDisplay: some View {
        HStack(spacing: 18) {
            Text(displayInput)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.24)
                .allowsTightening(true)

            Text("=")
                .foregroundStyle(.white.opacity(0.18))
                .font(.system(size: 46, weight: .ultraLight, design: .rounded))
                .fixedSize()

            Text(displayOutput)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.20)
                .allowsTightening(true)
        }
        .font(.system(size: 49, weight: .ultraLight, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white)
        .padding(.horizontal, 27)
        .background(Color.black)
    }

    private var currencyRow:'''
s, count = amount_pattern.subn(amount_replacement, s, count=1)
if count != 1:
    raise SystemExit("Could not patch amount display")

circle_pattern = re.compile(r'private struct CircleIconButton: View \{.*?\n\}\n\nprivate struct CurrencyButton:', re.S)
circle_replacement = '''private struct CircleIconButton: View {
    let systemName: String
    var accent: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Color.white.opacity(0.085)))
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct CurrencyButton:'''
s, count = circle_pattern.subn(circle_replacement, s, count=1)
if count != 1:
    raise SystemExit("Could not patch favorite button")

currency_button_pattern = re.compile(r'private struct CurrencyButton: View \{.*?\n\}\n\nprivate struct KeyButton:', re.S)
currency_button_replacement = '''private struct CurrencyButton: View {
    let currency: CurrencyInfo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(currency.flag)
                    .font(.system(size: 31))
                    .frame(width: 48, height: 36, alignment: .center)

                VStack(alignment: .leading, spacing: 1) {
                    Text(currency.code)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(currency.name)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct KeyButton:'''
s, count = currency_button_pattern.subn(currency_button_replacement, s, count=1)
if count != 1:
    raise SystemExit("Could not patch currency row labels")

path.write_text(s, encoding="utf-8")
print("Applied refined MX Currency UI layout patch")
