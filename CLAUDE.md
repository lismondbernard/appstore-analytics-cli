# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run Commands

### Toolchain
The project requires **Swift 5.9+** (currently building cleanly on **6.2.3**). If a `swiftly`-managed toolchain on PATH is older than 5.9, point swiftly at Xcode's bundled toolchain (no separate download needed):

```bash
swiftly use xcode   # creates/updates .swift-version → "xcode"
```

The repo's `.swift-version` file pins this project to the active Xcode toolchain for any contributor using swiftly. Alternatives: `swiftly install latest && swiftly use latest`, or prefix commands with `xcrun` to bypass swiftly.

## Architecture Overview

### Authentication Flow
1. User runs `configure` command, providing credentials
2. `ConfigManager` saves credentials to `~/.appstore-analytics-config.json` with 600 permissions
3. `JWTManager` validates credentials by creating `APIConfiguration` instance
4. JWT tokens are generated on-demand and cached for 18 minutes (buffer before 20-min expiry)
5. `APIClient` uses `APIProvider` from AppStoreConnect-Swift-SDK with auto-managed JWT

### Rate Limiting Strategy
- Hourly limit: 3,500 requests (buffer below Apple's 3,600 limit)
- Minute limit: 300 requests (buffer below Apple's limit)
- Token bucket implementation with automatic refill
- Blocks requests when limits exceeded until tokens available

## Key Design Patterns

### Configuration Management
- Single config file at `~/.appstore-analytics-config.json`
- Automatic chmod 600 on save for security
- Validates private key file existence and permissions on load
- Tilde path expansion for cross-user compatibility

### Multi-App Support
A single config holds one `default_app_id`, but `create-report` accepts a `--app-id <APP_ID>` flag that overrides it. The override threads from `Command.parseCreateReportCommand` → `CreateReportCommand.execute(appId:)` → `APIClient.createReportRequest(appId:)`. All other commands (`list-reports`, `download`, `status`, `delete-report`) operate by report request ID and are app-agnostic.

To extend the override to other commands, follow the same wiring: parser → Command enum case → execute() signature → APIClient call.

### Download Architecture
CSV downloads use parallel execution model:
- Up to 5 concurrent segment downloads
- Each report can have multiple instances
- Each instance can have multiple segments
- Directory structure: `{output-dir}/{report-id}/instance-{id}/segment-NNN.csv`
- `{output-dir}/{report-id}/manifest.json` records what each instance directory
  is — report name, category, granularity, processing date (see below)
- Optional merge functionality combines segments into single CSV

### Two report vocabularies — don't cross them

`ReportType` (`APP_STORE_PRODUCT_PAGE_VIEWS`, `APP_UNITS`, …) names the older
catalogue that `create-report` and `list-report-types` use. The Analytics API
returns a *different* set of names on each report and instance — "App Store
Discovery and Engagement Standard", "App Downloads Standard", "Platform App
Installs". The two never overlap.

`--report-type` on `download` and `status` matches the API's names, via
`ReportNameFilter`: case- and whitespace-insensitive substring, so `discovery`
selects both cuts and a full name selects one report. `download` treats a
no-match as an error and lists what is available, because silently downloading
all 100+ instances when a filter was requested is the worse failure. Both
commands previously gated the filter on `ReportType(rawValue:)` succeeding,
which meant a real report name skipped filtering entirely.

Use `status <ID>` to discover the names under a request before filtering.

### Never sum the downloaded CSVs

`download` fetches **every** instance under a report request, and those instances
overlap heavily. Summing the files inflates every count by three to five times.
Two independent causes, both visible in any refresh directory:

- **Three granularities of the same report.** Apple generates DAILY, WEEKLY
  (Monday-bucketed) and MONTHLY (1st-of-month-bucketed) instances covering the
  same events, plus rolling 3-day daily instances that re-state recent days. One
  report type routinely has 40+ instances over the same span.
- **"Standard" and "Detailed" are two cuts of one dataset**, not two datasets.
  Detailed adds Source Info / Campaign / Page Title and carries heavier privacy
  suppression. Adding them counts each event twice.

`download --granularity DAILY|WEEKLY|MONTHLY` removes the first cause at the
source, filtering on the granularity the API reports for each instance. Use it
on new pulls. It is not sufficient on its own: the rolling 3-day restatements
are themselves DAILY, so they still overlap each other.

`download` also writes **`manifest.json`** next to the instance directories,
recording each instance's report name, category and granularity. This matters
because none of that is recoverable from the CSVs — the report can be guessed
from the header shape, but granularity cannot: a single-date instance is
identical whether it is one day of a DAILY report or one bucket of a WEEKLY one.

`scripts/summarize-refresh.py` reads the manifest and does the rest: Standard
cut only, DAILY instances only, one instance per date preferring the narrowest,
which is Apple's freshest restatement.

Without a manifest the script falls back to asking whether an instance holds two
adjacent calendar dates. **That fallback undercounts** — it discards single-date
DAILY instances, which on sparse reports are frequently the only source for a
date. It cost 3 of Tennis Parent's 17 downloads (both August ones) and 6 of
Foreign Words TV's 11 August first-time downloads. It is exact only on dense
reports, where every date also appears in a multi-date instance; all three apps'
discovery figures were identical either way. Re-pull rather than trust it.

**Validate against Sales and Trends after any change to that logic.** The
de-duplicated download counts land within ~2% of `sales` units for the same
months; the naive sum is several times larger. That is the only external check
available, and it is what caught the error in the first place (project-docs
refreshes through Aug 4, 2026 were all inflated).

## Important Implementation Notes

### API Integration Status
All `APIClient` methods make real App Store Connect API calls through the SDK's
`provider` (type `APIProvider`), which is configured with JWT authentication.
Verified live against the account.

### Two data sources, and which one to trust

The CLI talks to two different App Store Connect APIs, and they answer different
questions:

- **Analytics reports** (`analyticsReportRequests` — `create-report`, `status`,
  `download`) are aggregate product analytics. Apple applies a **privacy
  threshold**: rows covering fewer than **five users or five unique devices are
  omitted entirely**, and some reports are not generated at all below a minimum.
  A handful of purchases is therefore invisible here — not zero, just withheld.
  Never answer a revenue question from these.
- **Sales and Trends** (`salesReports` — the `sales` command) is the transaction
  record. It is exact, has no privacy threshold, and reports a single unit as a
  single unit. This is the source for units and proceeds.

Finance reports (`financeReports`) are a third source, exposed by the SDK but not
yet wired up — they're the settled, invoice-level figures.

### Sales and Trends specifics

- **Vendor number is required and cannot be discovered.** The App Store Connect
  API has no endpoint that returns it; it lives in App Store Connect under
  Payments and Financial Reports. Stored as `vendor_number` in the config and
  overridable with `--vendor-number`.
- **Responses are gzipped TSV**, served as `Content-Type: application/a-gzip`.
  URLSession does not inflate that automatically (it would for a
  `Content-Encoding` response), so `CSVDownloader.decompressGzipIfNeeded` does
  it. The SDK returns `Request<Data>` for these endpoints — no typed model.
- **404 means "no report for that period"**, not an error. `fetchSalesReport`
  returns nil so a loop over several periods keeps going.
- **Only closed periods exist.** Requesting today's daily report, or the current
  month, 404s. `SalesReportPeriod` computes the most recent *closed* period per
  frequency, in UTC — a local calendar rolls the day at the wrong moment.
- **`Developer Proceeds` is per unit.** A 2-unit row at 3.50 is 7.00; summing the
  column alone undercounts revenue.
- **Product Type Identifier** distinguishes in-app purchases (`IA*` — IA1, IAY,
  IAC…) from app downloads (`1`, `1F`, `7`, `F1`…).
- **Proceeds are per settlement currency** and are never summed across them.

### File Permissions Security
The code enforces strict file permissions:
- Config file: Automatically set to 600 (owner read/write only)
- Private key: Warns if more permissive than 600
- Always use `chmod 600` for sensitive files

## Common Development Workflows

### Changing JWT Token Lifetime
Edit `JWTManager.swift`:
- Modify `tokenLifetime` constant (default: 18 minutes)
- Keep below 20 minutes (Apple's token expiry)

## Dependencies and External APIs

### App Store Connect Analytics API
Reference documentation:
- https://developer.apple.com/documentation/appstoreconnectapi/analytics
- Requires API key with Analytics permission from App Store Connect
- Rate limits: 3,600 requests/hour, exact per-minute limit varies

## Configuration File Format

`~/.appstore-analytics-config.json`, snake_case keys per `Configuration.swift` CodingKeys.

`vendor_number` is optional and only the `sales` command needs it; configs
written before sales support existed decode fine without it.

File is automatically created with 600 permissions by `ConfigManager`. The `default_app_id` is the app used by `create-report` when no `--app-id` flag is provided.

## Security Considerations

- Never log or print JWT tokens
- Never commit `.p8` private key files
- Config file contains sensitive credentials - always 600 permissions
- JWT tokens cached in memory only, never written to disk
- Private key path supports tilde expansion for user-specific paths
- Validate file permissions before reading sensitive files
