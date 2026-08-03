#!/usr/bin/env python3
"""Track App Store ratings for the studio's apps against their SSS-37 targets.

Why this is a standalone script and not an `appstore-analytics` subcommand:
the App Store Connect *Analytics Reports* API (what this CLI wraps) has no
ratings/reviews report type. Store-facing rating count + star average come from
Apple's public iTunes lookup API instead — no auth, no credentials needed.

Ratings are per-storefront. We sum counts across the storefronts below and
report a count-weighted average, plus the US storefront on its own (the primary
market the SSS-37 targets were written against).

Usage:
    python3 scripts/track-ratings.py            # table
    python3 scripts/track-ratings.py --json      # machine-readable
"""
import json
import sys
import urllib.request

# App Store IDs (verified against repo bundle IDs / Apple lookup API, 2026-08-03).
APPS = [
    {
        "name": "Tennis Parent",
        "id": "6759538350",           # com.silentspice.CaryTennisParent
        "target_count": 3,
        "target_avg": None,           # brief sets no star target for TP
    },
    {
        "name": "Foreign Words",
        "id": "598715944",            # com.silentspice.ForeignWords (iOS)
        "target_count": 5,
        "target_avg": 4.0,
    },
]

# Storefronts to aggregate. US first (primary market); the rest are Foreign
# Words' meaningful territories per the Marketing Director brief.
STOREFRONTS = ["us", "de", "gb", "fr", "es", "it", "jp", "tw"]


def lookup(app_id, country):
    url = "https://itunes.apple.com/lookup?id=%s&country=%s" % (app_id, country)
    with urllib.request.urlopen(url, timeout=15) as resp:
        data = json.load(resp)
    results = data.get("results") or []
    if not results:
        return None
    r = results[0]
    return {
        "count": int(r.get("userRatingCount") or 0),
        "avg": float(r.get("averageUserRating") or 0.0),
        "version": r.get("version"),
    }


def collect(app):
    per_store = {}
    total_count = 0
    weighted_sum = 0.0
    for cc in STOREFRONTS:
        row = lookup(app["id"], cc)
        if row is None:
            continue
        per_store[cc] = row
        total_count += row["count"]
        weighted_sum += row["avg"] * row["count"]
    global_avg = (weighted_sum / total_count) if total_count else 0.0
    us = per_store.get("us", {"count": 0, "avg": 0.0, "version": None})
    return {
        "name": app["name"],
        "id": app["id"],
        "target_count": app["target_count"],
        "target_avg": app["target_avg"],
        "us": us,
        "global_count": total_count,
        "global_avg": round(global_avg, 2),
        "per_store": per_store,
    }


def meets(app):
    """Target check uses the global aggregate count and average."""
    ok_count = app["global_count"] >= app["target_count"]
    ok_avg = app["target_avg"] is None or app["global_avg"] >= app["target_avg"]
    return ok_count and ok_avg


def main():
    as_json = "--json" in sys.argv
    report = [collect(a) for a in APPS]

    if as_json:
        print(json.dumps(report, indent=2))
        return

    print("App Store ratings vs SSS-37 targets")
    print("=" * 60)
    for a in report:
        status = "MET" if meets(a) else "NOT MET"
        avg_target = "n/a" if a["target_avg"] is None else "%.1f*" % a["target_avg"]
        print("\n%s  [%s]" % (a["name"], status))
        print("  target:  %d+ ratings, avg %s" % (a["target_count"], avg_target))
        print("  global:  %d ratings, %.2f* avg (across %d storefronts)"
              % (a["global_count"], a["global_avg"], len(STOREFRONTS)))
        print("  US only: %d ratings, %.1f* avg (v%s)"
              % (a["us"]["count"], a["us"]["avg"], a["us"]["version"]))
        nonzero = {cc: r["count"] for cc, r in a["per_store"].items() if r["count"]}
        if nonzero:
            breakdown = ", ".join("%s %d" % (cc, n) for cc, n in nonzero.items())
            print("  by store: %s" % breakdown)
    print()


if __name__ == "__main__":
    main()
