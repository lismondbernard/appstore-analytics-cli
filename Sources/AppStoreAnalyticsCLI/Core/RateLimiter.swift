import Foundation

/// Rate limiter using token bucket algorithm
/// Limits: 3,500 requests/hour, 300 requests/minute (conservative buffer below API limits)
actor RateLimiter {
    private let hourlyLimit: Int = 3500
    private let minuteLimit: Int = 300

    private var hourlyTokens: Int
    private var minuteTokens: Int
    private var lastHourlyRefill: Date
    private var lastMinuteRefill: Date

    init() {
        self.hourlyTokens = hourlyLimit
        self.minuteTokens = minuteLimit
        self.lastHourlyRefill = Date()
        self.lastMinuteRefill = Date()
    }

    /// Acquire permission to make an API request
    /// Blocks if rate limit would be exceeded
    func acquirePermit() async throws {
        // Refill tokens based on time elapsed
        refillTokens()

        // Wait if we're out of tokens
        while hourlyTokens <= 0 || minuteTokens <= 0 {
            // Wait 1 second and try again
            try await Task.sleep(nanoseconds: 1_000_000_000)
            refillTokens()
        }

        // Consume tokens
        hourlyTokens -= 1
        minuteTokens -= 1
    }

    private func refillTokens() {
        let now = Date()

        // Refill hourly tokens (1 hour = 3600 seconds)
        let hourlyElapsed = now.timeIntervalSince(lastHourlyRefill)
        if hourlyElapsed >= 3600 {
            hourlyTokens = hourlyLimit
            lastHourlyRefill = now
        }

        // Refill minute tokens (1 minute = 60 seconds)
        let minuteElapsed = now.timeIntervalSince(lastMinuteRefill)
        if minuteElapsed >= 60 {
            minuteTokens = minuteLimit
            lastMinuteRefill = now
        }
    }

    /// Get current token counts (for debugging/monitoring)
    func getStatus() -> (hourly: Int, minute: Int) {
        return (hourlyTokens, minuteTokens)
    }
}

/// Retry helper with exponential backoff
struct RetryHelper {
    static func withRetry<T>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var delay = initialDelay

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                Logger.error("Attempt \(attempt)/\(maxAttempts) failed: \(error.localizedDescription)")

                if attempt < maxAttempts {
                    Logger.info("Retrying in \(delay) seconds...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    delay *= 2  // Exponential backoff
                }
            }
        }

        throw lastError ?? NSError(domain: "RetryHelper", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "All retry attempts failed"
        ])
    }
}
