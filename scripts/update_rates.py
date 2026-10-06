#!/usr/bin/env python3
import datetime as dt
import html as html_lib
import json
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "rates.json"

UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15"
STREET_KINDS = {"parallel", "street", "informal", "open-market", "cash-market", "free-market"}
DIGIT_TRANS = str.maketrans(
    "٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹٬",
    "01234567890123456789,",
)


def now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def get_text(url: str, timeout: int = 20) -> str:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": UA,
            "Accept": "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9,ar;q=0.7",
            "Cache-Control": "no-cache",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", errors="replace")


def get_json(url: str):
    return json.loads(get_text(url))


def strip_html(raw: str) -> str:
    text = html_lib.unescape(re.sub(r"<[^>]+>", " ", raw))
    text = text.translate(DIGIT_TRANS)
    return re.sub(r"\s+", " ", text).strip()


def number(raw: str):
    if raw is None:
        return None
    s = str(raw).translate(DIGIT_TRANS).replace(",", "").strip()
    s = re.sub(r"[^0-9.\-]", "", s)
    if not s or s in {".", "-", "-."}:
        return None
    try:
        return float(s)
    except ValueError:
        return None


def last_match(pattern: str, text: str):
    matches = list(re.finditer(pattern, text, flags=re.S | re.I))
    return matches[-1] if matches else None


def quote(rate, source, kind="parallel", buy=None, sell=None, updated_at=None):
    return {
        "rate": float(rate),
        "meta": {
            "kind": kind,
            "source": source,
            "buy": float(buy) if buy is not None else None,
            "sell": float(sell) if sell is not None else None,
            "updatedAt": updated_at or now_iso(),
        },
    }


def valid_pair(buy, sell, low, high):
    return (
        buy is not None
        and sell is not None
        and low <= buy <= high
        and low <= sell <= high
        and buy <= sell
    )


def iraq_cash_per_usd(raw: str):
    digits = re.sub(r"\D", "", raw.translate(DIGIT_TRANS))
    if not digits:
        return None
    n = float(digits)
    return n / 100.0 if n >= 100000 else None


def iraq_board_per_usd(raw: str):
    s = raw.translate(DIGIT_TRANS).replace(",", ".")
    parts = s.split(".")
    # 160.400 = 160,400 IQD per $100 => 1,604 IQD per $1
    if len(parts) == 2 and len(parts[0]) == 3 and len(parts[1]) == 3:
        return float(parts[0] + parts[1]) / 100.0
    try:
        n = float(s)
    except ValueError:
        return None
    return n if n >= 1000 else None


def fetch_iqd_parallel():
    # Canonical Iraq source: the same live Harithiya/Kifah feed used by MX Dollar.
    # Harithiya is the primary benchmark; Kifah is the fallback. The converter
    # is intentionally keyed to the USD SELL board price requested for IQD.
    try:
        q = get_json("https://mxdollar.pages.dev/api/market")
        for key, label in (("harithiya", "Harithiya"), ("kifah", "Kifah")):
            board = q.get(key) or {}
            buy100 = number(board.get("buy"))
            sell100 = number(board.get("sell"))
            if buy100 is None or sell100 is None:
                continue
            buy = buy100 / 100.0
            sell = sell100 / 100.0
            if valid_pair(buy, sell, 1000, 3000):
                usd_meta = q.get("usd_meta") or {}
                updated_at = usd_meta.get("published_at") or q.get("updated_at")
                return quote(
                    sell,
                    f"Baghdad {label} board · @dollariraqi",
                    buy=buy,
                    sell=sell,
                    updated_at=updated_at,
                )
    except Exception as exc:
        print("IQD MX Dollar feed failed:", exc)

    # Fallback: parse Telegram directly. Prefer board quotes first so a
    # generic Baghdad cash quote can never override Harithiya/Kifah again.
    try:
        text = strip_html(get_text("https://t.me/s/dollariraqi"))

        m = last_match(r"(?:كفاح|حارثية)\\s*([0-9,.]+)\\s*\\|\\s*([0-9,.]+)", text)
        if m:
            buy = iraq_board_per_usd(m.group(1))
            sell = iraq_board_per_usd(m.group(2))
            if valid_pair(buy, sell, 1000, 3000):
                return quote(
                    sell,
                    "Baghdad Harithiya/Kifah board · @dollariraqi",
                    buy=buy,
                    sell=sell,
                )

        m = last_match(
            r"بغداد\\s*-\\s*صيرفات\\s*:\\s*([0-9,.]+)\\s*بيع\\s*-\\s*([0-9,.]+)\\s*شراء",
            text,
        )
        if m:
            sell = iraq_cash_per_usd(m.group(1))
            buy = iraq_cash_per_usd(m.group(2))
            if valid_pair(buy, sell, 1000, 3000):
                return quote(
                    sell,
                    "Baghdad street fallback · @dollariraqi",
                    buy=buy,
                    sell=sell,
                )
    except Exception as exc:
        print("IQD Telegram fallback failed:", exc)
    return None

def fetch_ars_blue():
    try:
        q = get_json("https://dolarapi.com/v1/dolares/blue")
        buy = float(q["compra"])
        sell = float(q["venta"])
        if valid_pair(buy, sell, 100, 10000):
            return quote(
                (buy + sell) / 2.0,
                "Argentina Blue · DolarApi",
                buy=buy,
                sell=sell,
                updated_at=q.get("fechaActualizacion"),
            )
    except Exception as exc:
        print("ARS override failed:", exc)
    return None


def fetch_irr_free_market():
    """Iran domestic free-market USD cash rate, quoted in IRR."""
    try:
        text = strip_html(get_text("https://www.tgju.org/profile/price_dollar_rl"))
        m = re.search(r"نرخ\s*فعلی\s*:*\s*([0-9][0-9,.]{4,})", text)
        value = number(m.group(1)) if m else None
        if value is not None and 100_000 <= value <= 20_000_000:
            return quote(value, "Iran free market · TGJU", kind="free-market")
    except Exception as exc:
        print("IRR override failed:", exc)
    return None


def fetch_syp_street():
    """SP Today publishes exchange-office buy/sell and both new/old SYP units."""
    try:
        text = strip_html(get_text("https://sp-today.com/en/currency/us-dollar"))
        m = re.search(
            r"Buy\s+([0-9,.]+)\s*SYP\s*\(new\)\s*([0-9,.]+)\s*old\s+Sell\s+"
            r"([0-9,.]+)\s*SYP\s*\(new\)\s*([0-9,.]+)\s*old",
            text,
            flags=re.I,
        )
        if m:
            buy = number(m.group(2))
            sell = number(m.group(4))
            if valid_pair(buy, sell, 1_000, 1_000_000):
                return quote(
                    (buy + sell) / 2.0,
                    "Syria street · SP Today",
                    kind="street",
                    buy=buy,
                    sell=sell,
                )
    except Exception as exc:
        print("SYP override failed:", exc)
    return None


def fetch_lbp_cash():
    """LBPRate wording is user-side: Buy USD / Sell USD, so invert to dealer bid/ask."""
    try:
        text = strip_html(get_text("https://lbprate.com/"))
        m = re.search(
            r"Buy\s+1\s+USD\s+at\s+([0-9,.]+)\s+LBP\s+Sell\s+1\s+USD\s+at\s+([0-9,.]+)\s+LBP",
            text,
            flags=re.I,
        )
        if m:
            dealer_sell = number(m.group(1))
            dealer_buy = number(m.group(2))
            if valid_pair(dealer_buy, dealer_sell, 10_000, 1_000_000):
                return quote(
                    (dealer_buy + dealer_sell) / 2.0,
                    "Lebanon cash · LBPRate",
                    kind="cash-market",
                    buy=dealer_buy,
                    sell=dealer_sell,
                )
    except Exception as exc:
        print("LBP override failed:", exc)
    return None


def fetch_cup_informal():
    try:
        text = strip_html(get_text("https://eltoque.com/tasas-de-cambio-cuba"))
        m = re.search(
            r"1\s*USD\s+D[oó]lar\s+Estadounidense.{0,100}?([0-9][0-9,.]+)\s*CUP",
            text,
            flags=re.I,
        )
        value = number(m.group(1)) if m else None
        if value is not None and 100 <= value <= 5_000:
            return quote(value, "Cuba informal · elTOQUE", kind="informal")
    except Exception as exc:
        print("CUP override failed:", exc)
    return None


def fetch_dzd_informal():
    try:
        text = strip_html(get_text("https://www.exchangedz.com/"))
        m = re.search(
            r"USD\s*(?:\$)?\s*US Dollars\s+Informal\s+Buy\s*:?\s*([0-9.]+)\s*DZD\s+"
            r"Sell\s*:?\s*([0-9.]+)\s*DZD",
            text,
            flags=re.I,
        )
        if m:
            buy = number(m.group(1))
            sell = number(m.group(2))
            if valid_pair(buy, sell, 100, 1_000):
                return quote(
                    (buy + sell) / 2.0,
                    "Algiers Square · ExchangeDZ",
                    kind="informal",
                    buy=buy,
                    sell=sell,
                )
    except Exception as exc:
        print("DZD override failed:", exc)
    return None


def fetch_ngn_black_market():
    try:
        text = strip_html(
            get_text("https://www.ngnrates.com/market/exchange-rates/us-dollar-to-naira/black-market")
        )
        m = re.search(
            r"Avg\.?\s*Exchange\s*Rates\s*:?\s*Sell\s*:?\s*₦?\s*([0-9,.]+).*?"
            r"Buy\s*:?\s*₦?\s*([0-9,.]+)",
            text,
            flags=re.I,
        )
        if m:
            dealer_sell = number(m.group(1))
            dealer_buy = number(m.group(2))
            if valid_pair(dealer_buy, dealer_sell, 500, 10_000):
                return quote(
                    (dealer_buy + dealer_sell) / 2.0,
                    "Nigeria black market · NGNRates",
                    kind="parallel",
                    buy=dealer_buy,
                    sell=dealer_sell,
                )
    except Exception as exc:
        print("NGN override failed:", exc)
    return None


def fetch_pkr_open_market():
    try:
        text = strip_html(get_text("https://www.forex.com.pk/"))
        m = re.search(r"US Dollar\s+([0-9.]+)\s+([0-9.]+)", text, flags=re.I)
        if m:
            buy = number(m.group(1))
            sell = number(m.group(2))
            if valid_pair(buy, sell, 100, 1_000):
                return quote(
                    (buy + sell) / 2.0,
                    "Pakistan open market · Forex.com.pk",
                    kind="open-market",
                    buy=buy,
                    sell=sell,
                )
    except Exception as exc:
        print("PKR override failed:", exc)
    return None


def fetch_etb_parallel():
    try:
        text = strip_html(get_text("https://ethiopianblackmarket.com/"))
        m = re.search(
            r"Black Market Rate\s+([0-9,.]+)\s*ETB\s+per\s+1\s+USD",
            text,
            flags=re.I,
        )
        value = number(m.group(1)) if m else None
        if value is not None and 50 <= value <= 1_000:
            return quote(value, "Ethiopia parallel · EBM", kind="parallel")
    except Exception as exc:
        print("ETB override failed:", exc)
    return None


def recent_previous_street(previous, code, max_age_hours=36):
    meta = (previous.get("meta") or {}).get(code)
    rate = (previous.get("rates") or {}).get(code)
    if not meta or not rate or meta.get("kind", "").lower() not in STREET_KINDS:
        return None

    raw_time = meta.get("updatedAt")
    if not raw_time:
        return None
    try:
        stamp = dt.datetime.fromisoformat(raw_time.replace("Z", "+00:00"))
        age = dt.datetime.now(dt.timezone.utc) - stamp.astimezone(dt.timezone.utc)
        if age.total_seconds() > max_age_hours * 3600:
            return None
    except Exception:
        return None

    return {"rate": float(rate), "meta": meta}


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)

    previous = {}
    if OUT.exists():
        try:
            previous = json.loads(OUT.read_text(encoding="utf-8"))
        except Exception:
            previous = {}

    rates = {"USD": 1.0}
    meta = {}

    try:
        base = get_json("https://open.er-api.com/v6/latest/USD")
        if base.get("result") == "success":
            rates.update(
                {k: float(v) for k, v in base.get("rates", {}).items() if isinstance(v, (int, float))}
            )
        else:
            raise RuntimeError("Open ER returned non-success")
    except Exception as exc:
        print("Broad market fallback failed:", exc)
        rates.update(previous.get("rates", {}))
        meta.update(previous.get("meta", {}))

    # These are local cash / open / informal markets where the on-the-ground
    # exchange rate can materially differ from institutional or electronic FX.
    street_sources = [
        ("IQD", fetch_iqd_parallel),
        ("ARS", fetch_ars_blue),
        ("IRR", fetch_irr_free_market),
        ("SYP", fetch_syp_street),
        ("LBP", fetch_lbp_cash),
        ("CUP", fetch_cup_informal),
        ("DZD", fetch_dzd_informal),
        ("NGN", fetch_ngn_black_market),
        ("PKR", fetch_pkr_open_market),
        ("ETB", fetch_etb_parallel),
    ]

    for code, loader in street_sources:
        fresh = loader()
        if fresh:
            rates[code] = fresh["rate"]
            meta[code] = fresh["meta"]
            print(f"{code}: {fresh['rate']:.6f} · {fresh['meta']['source']}")
            continue

        cached = recent_previous_street(previous, code)
        if cached:
            rates[code] = cached["rate"]
            meta[code] = cached["meta"]
            print(f"{code}: source unavailable; kept recent verified street quote")
        else:
            print(f"{code}: no verified street quote available; leaving broad market fallback")

    payload = {
        "base": "USD",
        "updatedAt": now_iso(),
        "rates": dict(sorted(rates.items())),
        "meta": dict(sorted(meta.items())),
    }

    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(rates)} rates to {OUT}; {len(meta)} verified street/open-market overrides")


if __name__ == "__main__":
    main()
