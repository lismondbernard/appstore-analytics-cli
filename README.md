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
- Swift 5.9+
- App Store Connect API credentials:
  - Issuer ID
  - API Key ID
  - Private Key (.p8 file)

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
  [--wait] \
  [--download]
```

**Options:**
- `--report-type`: Type of report (e.g., APP_STORE_PRODUCT_PAGE_VIEWS)
- `--start-date`: Start date in YYYY-MM-DD format
- `--end-date`: End date in YYYY-MM-DD format
- `--granularity`: Data granularity (default: DAILY)
- `--wait`: Wait for report completion
- `--download`: Automatically download when complete (requires --wait)

### list-reports

List available reports with optional filtering.

```bash
appstore-analytics list-reports \
  [--category discovery|commerce|usage|performance] \
  [--status created|processing|completed|failed] \
  [--format table|json]
```

**Options:**
- `--category`: Filter by report category
- `--status`: Filter by report status
- `--format`: Output format (default: table)

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

### Discovery
- `APP_STORE_PRODUCT_PAGE_VIEWS` - App Store Product Page Views
- `APP_STORE_SEARCH_TERMS` - App Store Search Terms
- `APP_IMPRESSIONS` - App Impressions
- `APP_STORE_REFERRERS` - App Store Referrers
- `APP_STORE_TOTAL_PAGE_VIEWS` - App Store Total Page Views

### Commerce
- `APP_UNITS` - App Units
- `APP_SALES` - App Sales
- `APP_PROCEEDS` - App Proceeds
- `PAYING_USERS` - Paying Users
- `APP_PURCHASES` - App Purchases

### Usage
- `APP_SESSIONS` - App Sessions
- `APP_INSTALLS` - App Installs
- `APP_USAGE` - App Usage
- `ACTIVE_DEVICES` - Active Devices
- `ACTIVE_LAST_30_DAYS` - Active Last 30 Days

### Performance
- `APP_CRASHES` - App Crashes
- `APP_PERFORMANCE` - App Performance

### Subscriptions
- `SUBSCRIPTION_EVENTS` - Subscription Events
- `SUBSCRIBER_ACTIVITY` - Subscriber Activity
- `SUBSCRIPTION_RETENTION` - Subscription Retention

You can also run `appstore-analytics list-report-types` to see this list. See [Apple's documentation](https://developer.apple.com/documentation/appstoreconnectapi/analytics) for more details.

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
