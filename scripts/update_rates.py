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


def get_text(url: str, timeout: int = 20) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", errors="replace")


def get_json(url: str):
    return json.loads(get_text(url))


def last_match(pattern: str, text: str):
    matches = list(re.finditer(pattern, text, flags=re.S))
    return matches[-1] if matches else None


def iraq_cash_per_usd(raw: str):
    digits = re.sub(r"\D", "", raw)
    if not digits:
        return None
    n = float(digits)
    return n / 100.0 if n >= 100000 else None


def iraq_board_per_usd(raw: str):
    s = raw.replace(",", ".")
    parts = s.split(".")
    # 160.400 = 160,400 IQD per $100 => 1,604 IQD per $1
    if len(parts) == 2 and len(parts[0]) == 3 and len(parts[1]) == 3:
        return float(parts[0] + parts[1]) / 100.0
    try:
        n = float(s)
    except ValueError:
        return None
    # 1596.50 already represents roughly 1,596.5 IQD per $1.
    return n if n >= 1000 else None


def fetch_iqd_parallel():
    try:
        raw = get_text("https://t.me/s/dollariraqi")
        text = html_lib.unescape(re.sub(r"<[^>]+>", " ", raw))
        m = last_match(r"بغداد\s*-\s*صيرفات\s*:\s*([0-9,.]+)\s*بيع\s*-\s*([0-9,.]+)\s*شراء", text)
        if m:
            sell = iraq_cash_per_usd(m.group(1))
            buy = iraq_cash_per_usd(m.group(2))
            if buy and sell:
                return {
                    "rate": (buy + sell) / 2.0,
                    "meta": {
                        "kind": "parallel",
                        "source": "Baghdad street · @dollariraqi",
                        "buy": buy,
                        "sell": sell,
                        "updatedAt": dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
                    },
                }

        m = last_match(r"(?:كفاح|حارثية)\s*([0-9,.]+)\s*\|\s*([0-9,.]+)", text)
        if m:
            buy = iraq_board_per_usd(m.group(1))
            sell = iraq_board_per_usd(m.group(2))
            if buy and sell:
                return {
                    "rate": (buy + sell) / 2.0,
                    "meta": {
                        "kind": "parallel",
                        "source": "Baghdad parallel board · @dollariraqi",
                        "buy": buy,
                        "sell": sell,
                        "updatedAt": dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
                    },
                }
    except Exception as exc:
        print("IQD override failed:", exc)
    return None


def fetch_ars_blue():
    try:
        q = get_json("https://dolarapi.com/v1/dolares/blue")
        buy = float(q["compra"])
        sell = float(q["venta"])
        if buy > 0 and sell > 0:
            return {
                "rate": (buy + sell) / 2.0,
                "meta": {
                    "kind": "parallel",
                    "source": "Argentina Blue · DolarApi",
                    "buy": buy,
                    "sell": sell,
                    "updatedAt": q.get("fechaActualizacion"),
                },
            }
    except Exception as exc:
        print("ARS override failed:", exc)
    return None


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
            rates.update({k: float(v) for k, v in base.get("rates", {}).items() if isinstance(v, (int, float))})
    except Exception as exc:
        print("Broad market fallback failed:", exc)
        rates.update(previous.get("rates", {}))
        meta.update(previous.get("meta", {}))

    iqd = fetch_iqd_parallel()
    if iqd:
        rates["IQD"] = iqd["rate"]
        meta["IQD"] = iqd["meta"]

    ars = fetch_ars_blue()
    if ars:
        rates["ARS"] = ars["rate"]
        meta["ARS"] = ars["meta"]

    payload = {
        "base": "USD",
        "updatedAt": dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
        "rates": dict(sorted(rates.items())),
        "meta": meta,
    }

    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(rates)} rates to {OUT}")


if __name__ == "__main__":
    main()
