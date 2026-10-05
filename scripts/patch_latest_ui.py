from pathlib import Path
import re

path = Path("MXCurrency/ContentView.swift")
s = path.read_text(encoding="utf-8")

s = s.replace('header\n                        .frame(height: 76)', 'header\n                        .frame(height: 88)')

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
            .padding(.horizontal, 30)

            Text(headerRateText)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(1)
                .minimumScaleFactor(0.66)
                .padding(.horizontal, 92)
        }
        .padding(.top, 4)
        .background(Color.black)
    }

    private var amountDisplay:'''
s, count = header_pattern.subn(header_replacement, s, count=1)
if count != 1:
    raise SystemExit("Could not patch header layout")

currency_button_pattern = re.compile(r'private struct CurrencyButton: View \{.*?\n\}\n\nprivate struct KeyButton:', re.S)
currency_button_replacement = '''private struct CurrencyButton: View {
    let currency: CurrencyInfo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(currency.flag)
                    .font(.system(size: 34))

                VStack(alignment: .leading, spacing: 1) {
                    Text(currency.code)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(currency.name)
                        .font(.system(size: 11.5, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
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
print("Applied latest MX Currency UI layout patch")
