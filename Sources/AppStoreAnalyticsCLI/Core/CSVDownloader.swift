import Foundation
import Compression

enum DownloadError: LocalizedError {
    case invalidURL
    case downloadFailed(url: String, reason: String)
    case fileSaveFailed(path: String, reason: String)
    case mergeFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid download URL"
        case .downloadFailed(let url, let reason):
            return "Failed to download from \(url): \(reason)"
        case .fileSaveFailed(let path, let reason):
            return "Failed to save file to \(path): \(reason)"
        case .mergeFailed(let reason):
            return "Failed to merge CSV files: \(reason)"
        }
    }
}

/// Progress tracking for downloads
struct DownloadProgress {
    let totalSegments: Int
    var downloadedSegments: Int
    var failedSegments: Int
    var totalBytes: Int64
    var downloadedBytes: Int64

    var percentComplete: Double {
        guard totalSegments > 0 else { return 0 }
        return Double(downloadedSegments) / Double(totalSegments) * 100
    }

    mutating func markSegmentComplete(bytes: Int64) {
        downloadedSegments += 1
        downloadedBytes += bytes
    }

    mutating func markSegmentFailed() {
        failedSegments += 1
    }
}

/// CSV downloader with parallel download support
actor CSVDownloader {
    private let maxConcurrentDownloads = 5
    private let maxRetries = 3

    /// Download report segments to a directory
    func downloadSegments(
        segments: [AnalyticsReportSegment],
        outputDirectory: String,
        overwrite: Bool = false
    ) async throws -> [String] {
        guard !segments.isEmpty else {
            Logger.info("No segments to download")
            return []
        }

        // Create output directory
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            atPath: outputDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Initialize progress tracking
        let totalBytes = segments.compactMap(\.sizeInBytes).reduce(Int64(0)) { Int64($0) + Int64($1) }
        var progress = DownloadProgress(
            totalSegments: segments.count,
            downloadedSegments: 0,
            failedSegments: 0,
            totalBytes: totalBytes,
            downloadedBytes: 0
        )

        Logger.info("Downloading \(segments.count) segment(s) to \(outputDirectory)")
        Logger.info("Total size: \(formatBytes(progress.totalBytes))")

        // Download segments in parallel (max 5 concurrent)
        var downloadedPaths: [String] = []

        for batch in segments.chunked(into: maxConcurrentDownloads) {
            let batchPaths = try await withThrowingTaskGroup(of: String?.self) { group in
                for (index, segment) in batch.enumerated() {
                    group.addTask {
                        return try await self.downloadSegment(
                            segment: segment,
                            outputDirectory: outputDirectory,
                            segmentNumber: segments.firstIndex(where: { $0.id == segment.id }) ?? index,
                            overwrite: overwrite
                        )
                    }
                }

                var paths: [String] = []
                for try await path in group {
                    if let path = path {
                        paths.append(path)
                        progress.markSegmentComplete(bytes: 0)
                        self.displayProgress(progress)
                    } else {
                        progress.markSegmentFailed()
                    }
                }
                return paths
            }

            downloadedPaths.append(contentsOf: batchPaths)
        }

        if progress.failedSegments > 0 {
            Logger.error("\(progress.failedSegments) segment(s) failed to download")
        }

        Logger.success("Downloaded \(downloadedPaths.count) of \(segments.count) segment(s)")
        return downloadedPaths.sorted()
    }

    /// Download a single segment with retry logic
    private func downloadSegment(
        segment: AnalyticsReportSegment,
        outputDirectory: String,
        segmentNumber: Int,
        overwrite: Bool
    ) async throws -> String? {
        guard let urlString = segment.url, let url = URL(string: urlString) else {
            Logger.error("Invalid URL for segment \(segment.id)")
            return nil
        }

        let filename = "segment-\(String(format: "%03d", segmentNumber)).csv"
        let outputPath = "\(outputDirectory)/\(filename)"

        // Check if file exists and skip if not overwriting
        if FileManager.default.fileExists(atPath: outputPath) && !overwrite {
            Logger.info("Skipping \(filename) (already exists)")
            return outputPath
        }

        // Retry download up to maxRetries times
        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    throw DownloadError.downloadFailed(
                        url: urlString,
                        reason: "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                    )
                }

                // Verify checksum if provided
                if let checksum = segment.checksum {
                    // TODO: Implement checksum verification
                    _ = checksum
                }

                // Decompress gzip if needed
                let outputData = Self.decompressGzipIfNeeded(data)

                // Save to file
                try outputData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)

                return outputPath
            } catch {
                if attempt < maxRetries {
                    Logger.error("Attempt \(attempt) failed for \(filename): \(error.localizedDescription)")
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                } else {
                    Logger.error("Failed to download \(filename) after \(maxRetries) attempts")
                    return nil
                }
            }
        }

        return nil
    }

    /// Merge multiple CSV files into one
    func mergeCSVFiles(paths: [String], outputPath: String) async throws {
        guard !paths.isEmpty else {
            throw DownloadError.mergeFailed(reason: "No files to merge")
        }

        Logger.info("Merging \(paths.count) CSV file(s) into \(outputPath)")

        let fileManager = FileManager.default
        var mergedContent = ""
        var headerWritten = false

        for path in paths {
            guard fileManager.fileExists(atPath: path) else {
                Logger.error("File not found: \(path)")
                continue
            }

            let content = try String(contentsOfFile: path, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            for (index, line) in lines.enumerated() {
                // Skip empty lines
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    continue
                }

                // Handle header row
                if index == 0 {
                    if !headerWritten {
                        mergedContent += line + "\n"
                        headerWritten = true
                    }
                    continue
                }

                // Add data row
                mergedContent += line + "\n"
            }
        }

        // Write merged content
        try mergedContent.write(toFile: outputPath, atomically: true, encoding: .utf8)
        Logger.success("Merged CSV saved to \(outputPath)")
    }

    // MARK: - Gzip Decompression

    /// Decompress data if it has a gzip header (magic bytes 0x1f 0x8b)
    private static func decompressGzipIfNeeded(_ data: Data) -> Data {
        guard data.count >= 2, data[0] == 0x1f, data[1] == 0x8b else {
            return data
        }

        // Strip the 10-byte gzip header (and optional fields) to get raw deflate stream
        var offset = 10
        let flags = data[3]
        if flags & 0x04 != 0 { // FEXTRA
            guard data.count > offset + 2 else { return data }
            let extraLen = Int(data[offset]) | (Int(data[offset + 1]) << 8)
            offset += 2 + extraLen
        }
        if flags & 0x08 != 0 { // FNAME
            while offset < data.count && data[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x10 != 0 { // FCOMMENT
            while offset < data.count && data[offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x02 != 0 { offset += 2 } // FHCRC

        guard offset < data.count else { return data }

        let compressedPayload = Data(data[offset..<(data.count - 8)]) // exclude trailing CRC32 + size
        let bufferSize = 1024 * 1024 // 1 MB chunks
        var result = Data()

        let srcArray = [UInt8](compressedPayload)
        let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { dstBuffer.deallocate() }

        var stream = compression_stream(dst_ptr: dstBuffer, dst_size: bufferSize, src_ptr: UnsafePointer(dstBuffer), src_size: 0, state: nil)
        let initStatus = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
        guard initStatus == COMPRESSION_STATUS_OK else { return data }
        defer { compression_stream_destroy(&stream) }

        srcArray.withUnsafeBufferPointer { srcBuffer in
            stream.src_ptr = srcBuffer.baseAddress!
            stream.src_size = srcBuffer.count
            stream.dst_ptr = dstBuffer
            stream.dst_size = bufferSize

            while true {
                let status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                let outputSize = bufferSize - stream.dst_size
                if outputSize > 0 {
                    result.append(dstBuffer, count: outputSize)
                    stream.dst_ptr = dstBuffer
                    stream.dst_size = bufferSize
                }
                if status == COMPRESSION_STATUS_END { break }
                if status == COMPRESSION_STATUS_ERROR { result = Data(); break }
            }
        }

        return result.isEmpty ? data : result
    }

    // MARK: - Helper Methods

    private nonisolated func displayProgress(_ progress: DownloadProgress) {
        let percent = Int(progress.percentComplete)
        let barLength = 40
        let filledLength = Int(Double(barLength) * progress.percentComplete / 100.0)
        let bar = String(repeating: "=", count: filledLength) + String(repeating: " ", count: barLength - filledLength)

        Logger.info("[\(bar)] \(percent)% (\(progress.downloadedSegments)/\(progress.totalSegments))")
    }

    private nonisolated func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
