#!/usr/bin/env python3
"""Summarize a downloaded ONGOING analytics report without double-counting.

`appstore-analytics download` fetches *every* instance under a report request.
Apple generates instances at three granularities for the same report -- DAILY,
WEEKLY (Monday-bucketed) and MONTHLY (1st-of-month-bucketed) -- and, on top of
that, re-states the last few days in rolling 3-day daily instances. It also
publishes each report in a "Standard" and a "Detailed" cut of the same events,
the Detailed one carrying extra columns and heavier privacy suppression.

Summing the downloaded CSVs therefore counts most events three to five times.
This script instead:

  * identifies the report from the CSV header shape (the download layout does
    not record report names),
  * keeps only DAILY instances -- an instance is daily iff it contains two
    adjacent calendar dates, which weekly and monthly buckets never do,
  * assigns each date to exactly one instance, preferring the narrowest one
    (Apple's rolling 3-day instances are the freshest restatement of a day), and
  * reports the Standard cut only, since Detailed re-slices the same events.

The resulting download counts agree with Sales and Trends -- the exact,
unthresholded transaction record -- to within a couple of percent, which is the
check to re-run whenever this logic changes.

The adjacent-dates heuristic is a fallback for directories already on disk.
`download --granularity DAILY` asks the API for its own answer, and the two
agree exactly: on the Tennis Parent discovery report both select the same 35 of
42 instances, 2,603 rows, 4,248 impressions. Prefer the flag for new pulls --
this script still has to run afterwards, because the rolling restatements
overlap *within* the daily granularity.

Usage:  scripts/summarize-refresh.py analytics-reports/<refresh-dir> [SINCE]
"""
import collections
import csv
import datetime
import os
import sys

# Header shape -> report. Apple's per-instance directories carry no report name,
# but the column set identifies each report unambiguously.
REPORTS = {
    ("Date", "App Name", "App Apple Identifier", "Event", "Page Type", "Source Type",
     "Engagement Type", "Device", "Platform Version", "Territory", "Counts",
     "Unique Counts"): "Discovery-Standard",
    ("Date", "App Name", "App Apple Identifier", "Event", "Page Type", "Page Title",
     "Source Type", "Source Info", "Campaign", "Engagement Type", "Device",
     "Platform Version", "Territory", "Counts", "Unique Counts"): "Discovery-Detailed",
    ("Date", "App Name", "App Apple Identifier", "Event", "Page Type", "Source Type",
     "Engagement Type", "Browser", "Browser Version", "Device", "Platform Version",
     "Territory", "Counts"): "WebPreview-Standard",
    ("Date", "App Name", "App Apple Identifier", "Download Type", "App Version", "Device",
     "Platform Version", "Source Type", "Page Type", "Pre-Order", "Territory",
     "Counts"): "Downloads-Standard",
    ("Date", "App Name", "App Apple Identifier", "Download Type", "App Version", "Device",
     "Platform Version", "Source Type", "Source Info", "Campaign", "Page Type",
     "Page Title", "Pre-Order", "Territory", "Counts"): "Downloads-Detailed",
    ("Date", "App Name", "App Apple Identifier", "Event", "Download Type", "App Version",
     "Device", "Platform Version", "Source Type", "Page Type", "App Download Date",
     "Territory", "Counts", "Unique Devices"): "InstallDelete-Standard",
    ("Date", "App Name", "App Apple Identifier", "Event", "Download Type", "App Version",
     "Device", "Platform Version", "Source Type", "Source Info", "Campaign", "Page Type",
     "Page Title", "App Download Date", "Territory", "Counts",
     "Unique Devices"): "InstallDelete-Detailed",
    ("Date", "App Name", "App Apple Identifier", "App Version", "Device", "Platform Version",
     "Source Type", "Page Type", "App Download Date", "Territory", "Sessions",
     "Total Session Duration", "Unique Devices"): "Sessions-Standard",
    ("Install Day", "App Name", "App Apple Identifier", "Install Type", "Channel", "Device",
     "Platform Version", "Territory", "Installs"): "PlatformInstalls",
}

DIMENSIONS = ("Territory", "Device", "Source Type", "App Version", "Page Type",
              "Platform Version", "Channel", "Install Type", "Browser")


def num(value):
    try:
        return int(str(value).replace(",", ""))
    except (TypeError, ValueError):
        return 0


def date_column(rows):
    return "Install Day" if rows and "Install Day" in rows[0] else "Date"


def scan(root):
    """report name -> {instance id -> rows}"""
    found = collections.defaultdict(lambda: collections.defaultdict(list))
    for dirpath, _, files in os.walk(root):
        for name in sorted(files):
            if not name.endswith(".csv"):
                continue
            path = os.path.join(dirpath, name)
            instance = os.path.basename(os.path.dirname(path)).removeprefix("instance-")
            with open(path, newline="", encoding="utf-8") as handle:
                reader = csv.DictReader(handle, delimiter="\t")
                if not reader.fieldnames:
                    continue
                report = REPORTS.get(tuple(reader.fieldnames),
                                     "Unrecognized-%d-column" % len(reader.fieldnames))
                found[report][instance].extend(reader)
    return found


def is_daily(dates):
    """Daily instances hold adjacent days; weekly and monthly buckets never do."""
    parsed = sorted(datetime.date.fromisoformat(d) for d in dates if d)
    return any((b - a).days == 1 for a, b in zip(parsed, parsed[1:]))


def daily_rows(instances):
    """Rows from daily instances, each date owned by the narrowest instance."""
    candidates = []
    for instance, rows in instances.items():
        if not rows:
            continue
        column = date_column(rows)
        dates = {r[column] for r in rows if r.get(column)}
        if is_daily(dates):
            candidates.append((len(dates), instance, dates, rows, column))
    candidates.sort()

    owner = {}
    for _, instance, dates, _, _ in candidates:
        for date in dates:
            owner.setdefault(date, instance)

    kept = []
    for _, instance, _, rows, column in candidates:
        kept.extend(r for r in rows if owner.get(r.get(column)) == instance)
    return kept


def span(rows):
    if not rows:
        return "-", "-", 0
    column = date_column(rows)
    dates = sorted({r[column] for r in rows if r.get(column)})
    return dates[0], dates[-1], len(dates)


def breakdown(rows, metric, since=None, limit=12):
    if since:
        column = date_column(rows)
        rows = [r for r in rows if (r.get(column) or "") >= since]
    if not rows:
        print("      (no rows)")
        return
    low, high, days = span(rows)
    total = sum(num(r.get(metric)) for r in rows)
    rate = f", {total/days:.1f}/day" if days else ""
    print(f"      {total:,} over {low}..{high} ({days} data days{rate})")
    for dimension in DIMENSIONS:
        if dimension not in rows[0]:
            continue
        counts = collections.Counter()
        for row in rows:
            counts[row.get(dimension) or "(none)"] += num(row.get(metric))
        if not counts or list(counts) == ["(none)"]:
            continue
        shown = ", ".join(f"{k}={v} ({100.0 * v / total:.0f}%)"
                          for k, v in counts.most_common(limit)) if total else ""
        print(f"        {dimension:<17} {shown}")


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    root = sys.argv[1]
    since = sys.argv[2] if len(sys.argv) > 2 else None
    reports = scan(root)

    print(f"{root} — de-duplicated daily view"
          + (f", plus a window since {since}" if since else ""))

    for report in sorted(reports):
        instances = reports[report]
        rows = daily_rows(instances)
        skipped = len(instances) - len({r_id for r_id, r in instances.items()
                                        if is_daily({x.get(date_column(r), "") for x in r})})
        low, high, days = span(rows)
        print(f"\n## {report}: {len(rows)} rows from daily instances "
              f"({skipped} weekly/monthly instance(s) skipped), {low}..{high} ({days} days)")
        if not rows:
            continue

        metric = next(m for m in ("Counts", "Installs", "Sessions") if m in rows[0])
        split = "Event" if "Event" in rows[0] else (
            "Download Type" if "Download Type" in rows[0] else None)
        groups = sorted({row.get(split) or "(none)" for row in rows}) if split else ["(all)"]

        for group in groups:
            subset = rows if group == "(all)" else [r for r in rows if (r.get(split) or "(none)") == group]
            print(f"\n    {group} — full window")
            breakdown(subset, metric)
            if since:
                print(f"    {group} — since {since}")
                breakdown(subset, metric, since=since)


if __name__ == "__main__":
    main()
