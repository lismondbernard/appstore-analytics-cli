# App Store Analytics CLI

A command-line interface for the App Store Connect Analytics API, designed to generate and download analytics reports for your iOS apps.

## Features

- **Easy Authentication**: Configure once with your App Store Connect API credentials
- **Report Generation**: Create analytics reports with various types and date ranges
- **Automated Downloads**: Download CSV reports automatically
- **Status Monitoring**: Track report processing status with report type details
- **Report Management**: Delete report requests and list available report types
- **Secure**: Credentials stored with proper file permissions (600)

## Requirements

- macOS 13.0+ (Ventura)
- Swift 5.9+ (Xcode 15+ provides this; latest Xcode ships Swift 6.x)
- App Store Connect API credentials:
  - Issuer ID
  - API Key ID
  - Private Key (.p8 file)

### Toolchain note for swiftly users

If you use [swiftly](https://www.swift.org/install/) as your Swift version manager, ensure it's pointing at a 5.9+ toolchain. The simplest option is to use Xcode's bundled toolchain (no extra download):

```bash
swiftly use xcode
```

This project includes a `.swift-version` file pinned to `xcode`. Alternatively run `swiftly install latest && swiftly use latest`, or bypass swiftly with `xcrun swift build`.

## Installation

### Build from Source

```bash
git clone <repository-url>
cd appstore-analytics-cli
swift build -c release
cp .build/release/appstore-analytics /usr/local/bin/
```

## Quick Start

### 1. Configure Credentials

First, set up your App Store Connect API credentials:

```bash
appstore-analytics configure \
  --issuer-id YOUR_ISSUER_ID \
  --key-id YOUR_KEY_ID \
  --private-key-path ~/AuthKey_XXXXXXXXXX.p8 \
  --app-id YOUR_APP_ID
```

Or run interactively:

```bash
appstore-analytics configure
```

This creates a configuration file at `~/.appstore-analytics-config.json` with secure permissions.

### 2. Create a Report

Generate an analytics report:

```bash
appstore-analytics create-report \
  --report-type APP_STORE_PRODUCT_PAGE_VIEWS \
  --start-date 2026-01-01 \
  --end-date 2026-01-14 \
  --granularity DAILY
```

### 3. Check Status

Monitor report processing:

```bash
appstore-analytics status <REPORT_REQUEST_ID>
```

Filter to show only a specific report type:

```bash
appstore-analytics status <REPORT_REQUEST_ID> --report-type APP_INSTALLS
```

Or watch continuously:

```bash
appstore-analytics status <REPORT_REQUEST_ID> --watch --interval 30
```

### 4. Download Report

Download the CSV files once complete:

```bash
appstore-analytics download <REPORT_REQUEST_ID>
```

Download only a specific report type:

```bash
appstore-analytics download <REPORT_REQUEST_ID> --report-type APP_INSTALLS
```

## Commands

### configure

Set up API credentials.

```bash
appstore-analytics configure \
  --issuer-id <ISSUER_ID> \
  --key-id <KEY_ID> \
  --private-key-path <PATH_TO_P8> \
  --app-id <APP_ID>
```

**Options:**
- `--issuer-id`: Your App Store Connect Issuer ID
- `--key-id`: Your API Key ID
- `--private-key-path`: Path to your .p8 private key file
- `--app-id`: Your default App ID

### create-report

Create a new analytics report request.

```bash
appstore-analytics create-report \
  --report-type <REPORT_TYPE> \
  --start-date <YYYY-MM-DD> \
  --end-date <YYYY-MM-DD> \
  [--granularity DAILY|WEEKLY|MONTHLY] \
  [--access-type ONE_TIME_SNAPSHOT|ONGOING] \
  [--app-id <APP_ID>] \
  [--wait] \
  [--download]
```

**Options:**
- `--report-type`: Type of report (e.g., APP_STORE_PRODUCT_PAGE_VIEWS). Ignored for `--access-type ONGOING`.
- `--start-date`: Start date in YYYY-MM-DD format. Ignored for `--access-type ONGOING`.
- `--end-date`: End date in YYYY-MM-DD format. Ignored for `--access-type ONGOING`.
- `--granularity`: Data granularity (default: DAILY)
- `--access-type`: `ONE_TIME_SNAPSHOT` (default, fixed date range) or `ONGOING` (continuous report — Apple keeps refreshing as new data arrives). `--ongoing` is a shortcut for `--access-type ONGOING`.
- `--app-id`: Override the `default_app_id` in config. Use this when collecting analytics for multiple apps without swapping configs.
- `--wait`: Wait for report completion
- `--download`: Automatically download when complete (requires --wait)

### list-reports

List available reports with optional filtering.

```bash
appstore-analytics list-reports \
  [--category discovery|commerce|usage|performance] \
  [--status created|processing|completed|failed] \
  [--format table|json] \
  [--app-id <APP_ID>]
```

**Options:**
- `--category`: Filter by report category
- `--status`: Filter by report status
- `--format`: Output format (default: table)
- `--app-id`: List another app's report requests instead of the configured default

Report requests belong to an app, so this command is app-scoped. The resolved app
ID is echoed in the table output, marked `(override)` or `(from config)`.

### download

Download report CSV files.

```bash
appstore-analytics download <REPORT_REQUEST_ID> \
  [--report-type <REPORT_TYPE>] \
  [--output-dir <DIR>] \
  [--merge] \
  [--overwrite]
```

**Options:**
- `--report-type`: Filter to download only a specific report type (e.g., APP_INSTALLS)
- `--output-dir`: Directory for downloaded files (default: ./analytics-reports)
- `--merge`: Merge all segments into a single CSV file
- `--overwrite`: Overwrite existing files

### status

Check the status of a report request.

```bash
appstore-analytics status <REPORT_REQUEST_ID> \
  [--report-type <REPORT_TYPE>] \
  [--watch] \
  [--interval <SECONDS>]
```

**Options:**
- `--report-type`: Filter to show only a specific report type (e.g., APP_INSTALLS)
- `--watch`: Continuously monitor until completion
- `--interval`: Polling interval in seconds (default: 30)

### delete-report

Delete an analytics report request.

```bash
appstore-analytics delete-report <REPORT_REQUEST_ID>
```

### list-report-types

List all available report types, optionally filtered by category.

```bash
appstore-analytics list-report-types [--category <CATEGORY>]
```

**Options:**
- `--category`: Filter by category (discovery, commerce, usage, performance, subscriptions)

## Report Types

> **Audited against a live `status` listing on 2026-09-05 (Foreign Words ONGOING
> request, 156 report types). None of the `UPPER_SNAKE_CASE` names below appear in
> Apple's response.** They are a legacy request vocabulary this CLI accepts and
> validates; they are not what you get back, and `create-report --report-type` does
> not restrict anything (Apple generates every report type per request regardless).
> Treat the list as historical and use `status <REPORT_REQUEST_ID>` for the real names.

### What the API actually returns

Apple names reports in human-readable form and groups them under five categories.
Counts are from the 2026-09-05 audit:

| Category | Count | Examples |
|---|---|---|
| `FRAMEWORK_USAGE` | 103 | Home Screen Widget Usage, PhotoKit Imports, Metal Command Queues |
| `PERFORMANCE` | 23 | CAMetalLayer Performance, Networking Connection Activity |
| `APP_USAGE` | 15 | App Sessions Standard/Detailed, App Crashes, App Store Installation and Deletion |
| `COMMERCE` | 10 | App Downloads Standard/Detailed, App Store Purchases, App Store Subscription Event Report |
| `APP_STORE_ENGAGEMENT` | 5 | App Store Discovery and Engagement Standard/Detailed, App Store Web Preview Engagement |

Most reports ship in a `Standard` and a `Detailed` cut. Pass these names to
`download --report-type`, which matches case-insensitively on any substring.

Note the mismatch with this CLI's own `--category` vocabulary (discovery,
engagement, commerce, usage, performance, subscriptions): there is no `discovery`
or `subscriptions` category in the API, and `FRAMEWORK_USAGE`, which is two thirds
of everything available, has no representation here at all.

**There is no organic search-terms report.** The live listing contains nothing
search-related (the sole "search" hit is Visual Intelligence Image Search Usage, a
framework metric). The closest real report, App Store Discovery and Engagement
Detailed, leaves `Source Info` empty on every "App Store search" row; only App and
Web referrer rows populate it. Apple Search Ads is the only first-party source of
search-term text.

### Legacy request vocabulary

Accepted by `create-report --report-type` and listed by `list-report-types`. Kept
for backward compatibility; see the caveat above before relying on any of it.

**Discovery:** `APP_STORE_PRODUCT_PAGE_VIEWS`, `APP_IMPRESSIONS`, `APP_STORE_REFERRERS`, `APP_STORE_TOTAL_PAGE_VIEWS`
**Commerce:** `APP_UNITS`, `APP_SALES`, `APP_PROCEEDS`, `PAYING_USERS`, `APP_PURCHASES`
**Usage:** `APP_SESSIONS`, `APP_INSTALLS`, `APP_USAGE`, `ACTIVE_DEVICES`, `ACTIVE_LAST_30_DAYS`
**Performance:** `APP_CRASHES`, `APP_PERFORMANCE`
**Subscriptions:** `SUBSCRIPTION_EVENTS`, `SUBSCRIBER_ACTIVITY`, `SUBSCRIPTION_RETENTION`

See [Apple's documentation](https://developer.apple.com/documentation/appstoreconnectapi/analytics) for more details.

## Examples

### Complete Workflow

```bash
# 1. Configure (one-time setup)
appstore-analytics configure

# 2. Create and auto-download a report
appstore-analytics create-report \
  --report-type APP_STORE_PRODUCT_PAGE_VIEWS \
  --start-date 2026-01-01 \
  --end-date 2026-01-14 \
  --wait \
  --download

# 3. List all your reports
appstore-analytics list-reports --format table

# 4. Download a specific report
appstore-analytics download abc-123-def --output-dir ./my-reports

# 5. Delete a report
appstore-analytics delete-report abc-123-def

# 6. List available report types
appstore-analytics list-report-types
appstore-analytics list-report-types --category commerce
```

### Multi-App Workflow

Track multiple apps from a single config by passing `--app-id` to `create-report` or `list-reports`. The override takes precedence over `default_app_id`.

`download`, `status` and `delete-report` take an explicit report request ID and are genuinely app-agnostic. `list-reports` is **not**: report requests belong to an app, and it is how you discover the request ID for one. Pass `--app-id` there or you get the default app's requests.

```bash
# Create an ONGOING report for a different app than the configured default
appstore-analytics create-report --access-type ONGOING --app-id 1071673538

# Re-download fresh data later (uses the report request ID, not the app ID)
appstore-analytics download <REPORT_REQUEST_ID> --output-dir analytics-reports/tvos-latest
```

## Security

- Configuration file (`~/.appstore-analytics-config.json`) is created with 600 permissions
- Private key file should have 600 permissions or more restrictive
- JWT tokens are cached in memory only (never written to disk)
- Tokens auto-refresh before 20-minute expiration

## Troubleshooting

### "Private key file has insecure permissions"

Fix with:
```bash
chmod 600 /path/to/AuthKey_XXXXXXXXXX.p8
```

### "Authentication failed"

1. Verify your credentials are correct
2. Ensure your API key has Analytics permission
3. Check that the .p8 file is valid
4. Re-run `appstore-analytics configure`

### "Rate limit exceeded"

The tool includes rate limiting, but if you hit API limits:
- Wait for the retry-after period
- Reduce request frequency

## Development

### Build

```bash
swift build
```

### Run

```bash
swift run appstore-analytics help
```

### Test

```bash
swift test
```

## License

[Your License Here]

## Contributing

[Contributing guidelines if applicable]

## Links

- [App Store Connect API Documentation](https://developer.apple.com/documentation/appstoreconnectapi)
- [Analytics API Endpoints](https://developer.apple.com/documentation/appstoreconnectapi/analytics)
- [Creating API Keys](https://developer.apple.com/documentation/appstoreconnectapi/creating_api_keys_for_app_store_connect_api)
