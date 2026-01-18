# App Store Analytics CLI - Setup Guide

Complete guide to setting up and using the App Store Analytics CLI tool.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Getting App Store Connect API Credentials](#getting-app-store-connect-api-credentials)
4. [Configuration](#configuration)
5. [Usage Examples](#usage-examples)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before you begin, ensure you have:

- **macOS 13.0+** (Ventura or later)
- **Swift 5.9+** (comes with Xcode 15+)
- **App Store Connect Account** with appropriate permissions
- **API Key** with Analytics access (Admin or Analytics role)

## Installation

### Build from Source

```bash
# Clone the repository
git clone <repository-url>
cd appstore-analytics-cli

# Build the project
swift build -c release

# Install to /usr/local/bin (optional)
sudo cp .build/release/appstore-analytics /usr/local/bin/
```

### Verify Installation

```bash
appstore-analytics version
# Should output: App Store Analytics CLI v1.0.0
```

---

## Getting App Store Connect API Credentials

You need three pieces of information to use this tool:

1. **Issuer ID** - Your App Store Connect team identifier
2. **Key ID** - Your API key identifier
3. **Private Key (.p8 file)** - Your API private key file

### Step 1: Access App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Sign in with your Apple ID
3. Navigate to **Users and Access** → **Keys** (under Integrations)

### Step 2: Create an API Key

1. Click the **"+"** button to generate a new key
2. Enter a **name** for your key (e.g., "Analytics CLI")
3. Select **Access**: Choose **Admin** or **App Manager** role
   - The key needs Analytics access to read report data
4. Click **Generate**

### Step 3: Download Your Private Key

**⚠️ IMPORTANT**: You can only download the private key **once**!

1. After generation, click **Download API Key**
2. Save the `.p8` file to a secure location (e.g., `~/Developer/AuthKey_XXXXXXXXXX.p8`)
3. Note your **Key ID** (shown above the download button)
4. Note your **Issuer ID** (shown at the top of the Keys page)

### Step 4: Secure Your Private Key

```bash
# Set restrictive permissions on your private key
chmod 600 ~/Developer/AuthKey_XXXXXXXXXX.p8

# Verify permissions
ls -la ~/Developer/AuthKey_XXXXXXXXXX.p8
# Should show: -rw------- (600)
```

### Step 5: Get Your App ID

You'll need your App ID (numeric ID, not bundle identifier):

1. In App Store Connect, go to **My Apps**
2. Select your app
3. Look at the URL: `https://appstoreconnect.apple.com/apps/{APP_ID}/appstore`
4. The `{APP_ID}` is your numeric App ID

---

## Configuration

### Interactive Configuration

Run the configure command without arguments for an interactive setup:

```bash
appstore-analytics configure
```

You'll be prompted for:
- Issuer ID
- Key ID (API Key ID)
- Private Key Path
- Default App ID
- Default Output Directory

### Command-Line Configuration

Alternatively, provide all values via command-line arguments:

```bash
appstore-analytics configure \
  --issuer-id "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
  --key-id "XXXXXXXXXX" \
  --private-key-path "~/Developer/AuthKey_XXXXXXXXXX.p8" \
  --app-id "1234567890"
```

### What Happens During Configuration

1. The tool validates that your private key file exists
2. It checks file permissions (warns if > 600)
3. It generates a test JWT token to verify credentials
4. It saves configuration to `~/.appstore-analytics-config.json` with chmod 600

### Configuration File Location

Your configuration is stored at:
```
~/.appstore-analytics-config.json
```

**Security**: This file contains sensitive credential references and is automatically created with `600` permissions (readable only by you).

---

## Usage Examples

### Example 1: Create a Simple Report

Generate a report for app store product page views:

```bash
appstore-analytics create-report \
  --report-type APP_STORE_PRODUCT_PAGE_VIEWS \
  --start-date 2026-01-01 \
  --end-date 2026-01-14 \
  --granularity DAILY
```

**Output:**
```
[INFO] Creating analytics report request for APP_STORE_PRODUCT_PAGE_VIEWS...
[OK] Report request created: report-abc12345
[SUCCESS] Report request created successfully
[INFO] Report Request ID: report-abc12345
[INFO] Report Type: APP_STORE_PRODUCT_PAGE_VIEWS
[INFO] Date Range: 2026-01-01 to 2026-01-14
[INFO] Granularity: DAILY
[INFO] Use 'appstore-analytics status report-abc12345' to check progress
```

### Example 2: Create Report and Wait for Completion

Use the `--wait` flag to monitor until the report is ready:

```bash
appstore-analytics create-report \
  --report-type APP_UNITS \
  --start-date 2026-01-01 \
  --end-date 2026-01-07 \
  --granularity WEEKLY \
  --wait
```

The tool will poll every 30 seconds and show status updates.

### Example 3: Create and Auto-Download

Use both `--wait` and `--download` to automatically download when ready:

```bash
appstore-analytics create-report \
  --report-type APP_SALES \
  --start-date 2025-12-01 \
  --end-date 2025-12-31 \
  --granularity MONTHLY \
  --wait \
  --download
```

### Example 4: Check Report Status

Monitor a report's progress:

```bash
# Check once
appstore-analytics status report-abc12345

# Continuous monitoring (checks every 30 seconds)
appstore-analytics status report-abc12345 --watch

# Custom polling interval (every 60 seconds)
appstore-analytics status report-abc12345 --watch --interval 60
```

### Example 5: List All Reports

View all your analytics reports:

```bash
# List all reports (table format)
appstore-analytics list-reports

# Filter by category
appstore-analytics list-reports --category commerce

# Filter by status
appstore-analytics list-reports --status completed

# Output as JSON
appstore-analytics list-reports --format json
```

### Example 6: Download a Report

Download CSV files for a completed report:

```bash
# Basic download
appstore-analytics download report-abc12345

# Download to specific directory
appstore-analytics download report-abc12345 --output-dir ~/Desktop/reports

# Download and merge multiple segments into one CSV
appstore-analytics download report-abc12345 --merge

# Overwrite existing files
appstore-analytics download report-abc12345 --overwrite
```

**Output structure:**
```
./analytics-reports/
└── report-abc12345/
    └── instance-xxxx/
        ├── segment-000.csv
        ├── segment-001.csv
        ├── segment-002.csv
        └── merged.csv (if --merge was used)
```

---

## Available Report Types

### Discovery Reports
- `APP_STORE_PRODUCT_PAGE_VIEWS` - Product page impressions and views
- `APP_STORE_SEARCH_TERMS` - Search terms used to find your app
- `APP_IMPRESSIONS` - Times your app appeared in results
- `APP_STORE_REFERRERS` - Sources that drove traffic to your page

### Commerce Reports
- `APP_UNITS` - App downloads and redownloads
- `APP_SALES` - Sales data and revenue
- `APP_PROCEEDS` - Net proceeds after Apple's commission
- `PAYING_USERS` - Number of paying users
- `APP_PURCHASES` - In-app purchase data

### Usage Reports
- `APP_SESSIONS` - App usage sessions
- `APP_INSTALLS` - New installations
- `APP_USAGE` - Time spent in app
- `ACTIVE_DEVICES` - Devices with your app installed
- `ACTIVE_LAST_30_DAYS` - 30-day active user count

### Performance Reports
- `APP_CRASHES` - Crash analytics and rates
- `APP_PERFORMANCE` - Performance metrics

### Subscription Reports
- `SUBSCRIPTION_EVENTS` - Subscription lifecycle events
- `SUBSCRIBER_ACTIVITY` - Subscriber behavior data
- `SUBSCRIPTION_RETENTION` - Retention analytics

Run `appstore-analytics create-report --report-type INVALID` to see the full list.

---

## Troubleshooting

### "Configuration file not found"

**Problem**: You haven't configured the tool yet.

**Solution**:
```bash
appstore-analytics configure
```

### "Private key file not found"

**Problem**: The path to your `.p8` file is incorrect or the file was moved.

**Solution**:
1. Verify the file exists: `ls -la ~/path/to/AuthKey_XXXXXXXXXX.p8`
2. Re-run configure with correct path

### "Private key file has insecure permissions"

**Problem**: Your private key file has overly permissive file permissions.

**Solution**:
```bash
chmod 600 ~/path/to/AuthKey_XXXXXXXXXX.p8
```

### "Authentication failed"

**Problem**: Your API credentials are invalid or expired.

**Solutions**:
1. Verify your Issuer ID and Key ID are correct
2. Check that your API key hasn't been revoked in App Store Connect
3. Ensure the API key has Analytics access
4. Re-download the private key if necessary (requires creating a new key)

### "Invalid report type"

**Problem**: The report type name is incorrect.

**Solution**:
- Report types must be in ALL_CAPS with underscores
- Example: `APP_STORE_PRODUCT_PAGE_VIEWS` (not `app-store-product-page-views`)
- Run with an invalid type to see available options

### "Invalid date format"

**Problem**: Dates must be in YYYY-MM-DD format.

**Solution**:
```bash
# Correct
--start-date 2026-01-01

# Incorrect
--start-date 01/01/2026
--start-date 2026-1-1
```

### "Date range exceeds maximum of 365 days"

**Problem**: You requested more than a year of data.

**Solution**: Split into multiple reports with smaller date ranges.

### "Rate limit exceeded"

**Problem**: You've exceeded Apple's API rate limits.

**Solution**:
- Wait for the retry period (shown in error message)
- The tool has built-in rate limiting, but multiple concurrent processes can trigger this

### "Report not ready for download"

**Problem**: You tried to download a report that's still processing.

**Solution**:
```bash
# Monitor until complete
appstore-analytics status <REPORT_ID> --watch

# Then download
appstore-analytics download <REPORT_ID>
```

---

## Tips & Best Practices

### 1. Use Meaningful Date Ranges

```bash
# Good: Last complete month
appstore-analytics create-report \
  --report-type APP_UNITS \
  --start-date 2025-12-01 \
  --end-date 2025-12-31

# Good: Last week
appstore-analytics create-report \
  --report-type APP_SESSIONS \
  --start-date 2026-01-06 \
  --end-date 2026-01-12
```

### 2. Automate with Scripts

Create a shell script for recurring reports:

```bash
#!/bin/bash
# weekly-report.sh

LAST_WEEK_START=$(date -v-14d +%Y-%m-%d)
LAST_WEEK_END=$(date -v-7d +%Y-%m-%d)

appstore-analytics create-report \
  --report-type APP_STORE_PRODUCT_PAGE_VIEWS \
  --start-date $LAST_WEEK_START \
  --end-date $LAST_WEEK_END \
  --granularity WEEKLY \
  --wait \
  --download
```

### 3. Merge Segments for Analysis

Large reports split into segments are easier to analyze when merged:

```bash
appstore-analytics download report-abc12345 --merge
```

Then analyze with your favorite tool (Excel, pandas, R, etc.)

### 4. Keep Your Private Key Secure

- Never commit your `.p8` file to version control
- Use restrictive file permissions (600)
- Store in a secure location outside your project directory
- Consider using a password manager or secrets vault

### 5. Monitor Report Processing

For time-sensitive reports, use watch mode:

```bash
appstore-analytics status report-abc12345 --watch --interval 15
```

---

## Advanced Usage

### Environment-Based Configuration

For CI/CD or multiple accounts, use different config files:

```bash
# Create environment-specific configs
appstore-analytics configure  # Creates ~/.appstore-analytics-config.json

# Or manually edit the config file
nano ~/.appstore-analytics-config.json
```

### Batch Processing

Process multiple report types in a script:

```bash
#!/bin/bash

REPORT_TYPES=(
  "APP_STORE_PRODUCT_PAGE_VIEWS"
  "APP_UNITS"
  "APP_SESSIONS"
)

for TYPE in "${REPORT_TYPES[@]}"; do
  appstore-analytics create-report \
    --report-type "$TYPE" \
    --start-date 2026-01-01 \
    --end-date 2026-01-31 \
    --wait \
    --download
done
```

---

## Getting Help

- Run `appstore-analytics help` for command overview
- Run `appstore-analytics <command> --help` for command-specific help
- Check the [README.md](README.md) for additional documentation
- Review [Apple's Analytics API docs](https://developer.apple.com/documentation/appstoreconnectapi/analytics)

---

## Next Steps

1. ✅ Configure your credentials
2. ✅ Create your first report
3. ✅ Download and analyze the data
4. 📊 Build dashboards and insights
5. 🤖 Automate regular reporting

Happy analyzing! 📈
