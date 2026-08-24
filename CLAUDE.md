# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

App Store Analytics CLI - A command-line tool for interacting with Apple's App Store Connect Analytics API. Enables programmatic creation, monitoring, and downloading of analytics reports for iOS apps.

**Language:** Swift 5.9+
**Platform:** macOS 13.0+ (Ventura)
**Primary Dependency:** AppStoreConnect-Swift-SDK v4.0.0+

## Build and Run Commands

### Toolchain
The project requires **Swift 5.9+** (currently building cleanly on **6.2.3**). If a `swiftly`-managed toolchain on PATH is older than 5.9, point swiftly at Xcode's bundled toolchain (no separate download needed):

```bash
swiftly use xcode   # creates/updates .swift-version → "xcode"
```

The repo's `.swift-version` file pins this project to the active Xcode toolchain for any contributor using swiftly. Alternatives: `swiftly install latest && swiftly use latest`, or prefix commands with `xcrun` to bypass swiftly.

### Building
```bash
# Debug build
swift build

# Release build
swift build -c release

# Run directly (development)
swift run appstore-analytics <command>

# Install to /usr/local/bin
sudo cp .build/release/appstore-analytics /usr/local/bin/
```

### Testing
47 tests under `Tests/AppStoreAnalyticsCLITests/`, covering gzip decompression,
Sales and Trends TSV parsing/aggregation, report-period arithmetic, report
name matching, and granularity parsing. None hit the network.

```bash
# Run tests (when implemented)
swift test

# Run specific test
swift test --filter <TestName>
```

### Development Commands
```bash
# Clean build artifacts
swift package clean

# Update dependencies
swift package update

# Show resolved dependencies
swift package show-dependencies
```

## Architecture Overview

### Command Pattern Architecture
The CLI uses a command-based architecture with clear separation of concerns:

- **Commands Layer** (`Sources/AppStoreAnalyticsCLI/Commands/`)
  - Each command is a separate file with static `execute()` method
  - Command routing happens in `Command.swift` enum via argument parsing
  - `main.swift` dispatches to appropriate command based on parsed arguments

- **Core Layer** (`Sources/AppStoreAnalyticsCLI/Core/`)
  - `APIClient`: Actor-based wrapper around AppStoreConnect-Swift-SDK
  - `JWTManager`: Actor managing JWT token lifecycle (18-min refresh cycle)
  - `ConfigManager`: Singleton for config file I/O with secure permissions
  - `RateLimiter`: Token bucket algorithm enforcing API rate limits
  - `CSVDownloader`: Parallel download manager with progress tracking

- **Models Layer** (`Sources/AppStoreAnalyticsCLI/Models/`)
  - `Configuration`: User config stored in `~/.appstore-analytics-config.json`
  - `ReportType`: 20+ report types across 5 categories (discovery, commerce, usage, performance, subscriptions)
  - `ReportRequest`: API request/response models

- **Utilities Layer** (`Sources/AppStoreAnalyticsCLI/Utilities/`)
  - `Logger`: Formatted console output ([OK], [ERROR], [SUCCESS], [INFO])
  - `UserInput`: Interactive prompts and tilde path expansion

### Concurrency Model
- Uses Swift structured concurrency (async/await)
- Two actors for thread-safe state management:
  - `APIClient`: Protects API configuration and rate limiter state
  - `JWTManager`: Protects JWT token cache and expiry dates
- All commands are async and called from `main.swift` with top-level await

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

### Error Handling
All major components have dedicated error enums conforming to `LocalizedError`:
- `ConfigManagerError`: Configuration and file permission issues
- `JWTManagerError`: JWT generation and validation failures
- `APIClientError`: API communication and rate limit errors
- `DownloadError`: Download and file operation failures

Errors provide actionable messages guiding users to resolution.

### Download Architecture
CSV downloads use parallel execution model:
- Up to 5 concurrent segment downloads
- Each report can have multiple instances
- Each instance can have multiple segments
- Directory structure: `{output-dir}/{report-id}/instance-{id}/segment-NNN.csv`
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

The instance directory names carry no report name, so the report is identified
by CSV header shape. `scripts/summarize-refresh.py` does the rest: Standard cut
only, daily instances only (an instance is daily iff it holds two adjacent
calendar dates — weekly and monthly buckets never do), one instance per date
preferring the narrowest, which is Apple's freshest restatement.

That heuristic exists so the script also works on directories pulled without
the flag. Where both apply they agree exactly — on the Tennis Parent discovery
report each selects the same 35 of 42 instances, 2,603 rows, 4,248 impressions.

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

### Date Validation
`CreateReportCommand` enforces:
- Date format: YYYY-MM-DD
- Maximum range: 365 days between start and end
- Start date must be before end date

### Adding New Commands
To add a new command:

1. Create `NewCommand.swift` in `Sources/AppStoreAnalyticsCLI/Commands/`
2. Add case to `Command` enum in `Command.swift`
3. Add argument parsing logic in `Command.parse()`
4. Add switch case in `main.swift` to dispatch to new command
5. Implement static `execute()` method with required parameters

### Working with Reports
Report types are strongly typed via `ReportType` enum. Each report has:
- Raw API value (e.g., "APP_STORE_PRODUCT_PAGE_VIEWS")
- Display name for user output
- Category association (discovery, commerce, usage, performance, subscriptions)

Access via:
```swift
let reportType = ReportType.appStoreProductPageViews
print(reportType.rawValue)      // "APP_STORE_PRODUCT_PAGE_VIEWS"
print(reportType.displayName)   // "App Store Product Page Views"
print(reportType.category)      // .discovery
```

## Common Development Workflows

### Adding a New Report Type
1. Add case to `ReportType` enum in `Models/ReportType.swift`
2. Add to appropriate category in `category` computed property
3. Add display name in `displayName` computed property

### Modifying Rate Limits
Edit `RateLimiter.swift`:
- Change `hourlyLimit` or `minuteLimit` properties
- Token buckets auto-refill at configured intervals

### Changing JWT Token Lifetime
Edit `JWTManager.swift`:
- Modify `tokenLifetime` constant (default: 18 minutes)
- Keep below 20 minutes (Apple's token expiry)

### Adding Progress Indicators
Use `Logger` utility for consistent output:
```swift
Logger.info("Processing...")     // [INFO] message
Logger.ok("Success")             // [OK] message
Logger.success("Complete!")      // [SUCCESS] message
Logger.error("Failed")           // [ERROR] message
```

## Dependencies and External APIs

### AppStoreConnect-Swift-SDK
The project depends on AvdLee's AppStoreConnect-Swift-SDK for:
- Type-safe API models
- JWT authentication handling
- `APIProvider` client
- `APIConfiguration` setup

Key types used from SDK:
- `APIConfiguration` - JWT credentials setup
- `APIProvider` - HTTP client for API calls
- Various analytics models (when implementing real API calls)

### App Store Connect Analytics API
Reference documentation:
- https://developer.apple.com/documentation/appstoreconnectapi/analytics
- Requires API key with Analytics permission from App Store Connect
- Rate limits: 3,600 requests/hour, exact per-minute limit varies

## Configuration File Format

`~/.appstore-analytics-config.json` (snake_case keys per `Configuration.swift` CodingKeys):
```json
{
  "api_key_id": "YOUR_KEY_ID",
  "default_app_id": "YOUR_APP_ID",
  "default_output_dir": "./analytics-reports",
  "issuer_id": "YOUR_ISSUER_ID",
  "private_key_path": "~/path/to/AuthKey_XXXXXXXXXX.p8",
  "vendor_number": "YOUR_VENDOR_NUMBER"
}
```

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
