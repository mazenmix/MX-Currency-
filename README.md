# MX Currency

Native iPhone currency converter by MazenmiX.

## Rate policy

MX Currency prefers practical market pricing instead of a government/central-bank peg:

- **Live market FX**: the app refreshes selected currency pairs from the public Yahoo Finance FX feed (`USDXXX=X`) when available.
- **Iraq / IQD parallel market**: direct override from the public `@dollariraqi` Telegram feed using Baghdad street/exchange-shop buy & sell quotes. The calculator uses the midpoint for quick conversion and keeps the source metadata.
- **Argentina / ARS blue market**: direct override from DolarApi's Blue Dollar quote.
- **Broad fallback**: ExchangeRate-API Open Access is used only when a live market/parallel provider is unavailable, so the app still supports a large ISO currency catalog.

A rate is never labeled **Parallel** unless it comes from a parallel/open-market source. Ordinary freely traded currencies are labeled **Market**.

## UI

- Clean dark converter screen with no logo or app name in the main interface.
- Currency selector with search and country flags.
- Favorites.
- Live rates screen.
- Numeric keypad and instant switch.
- Settings contains only **Decimal Points**.
- MazenmiX branding appears only at the bottom of Settings.

## Build

The project is generated with XcodeGen:

```bash
brew install xcodegen
xcodegen generate
open MXCurrency.xcodeproj
```

GitHub Actions builds an unsigned `MX-Currency.ipa` suitable for re-signing with a sideloading tool.
