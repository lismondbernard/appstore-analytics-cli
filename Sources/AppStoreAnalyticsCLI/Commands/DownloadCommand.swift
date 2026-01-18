import Foundation

struct DownloadCommand {
    static func execute(
        reportRequestId: String,
        outputDir: String?,
        merge: Bool,
        overwrite: Bool
    ) async throws {
        // Load configuration
        let config = try ConfigManager.shared.loadConfiguration()

        // Determine output directory
        let baseOutputDir = outputDir ?? config.defaultOutputDir
        let expandedOutputDir = UserInput.expandTildePath(baseOutputDir)

        Logger.info("Downloading report: \(reportRequestId)")

        // Create API client
        let apiClient = try APIClient(configuration: config)

        // Check report status first
        Logger.info("Checking report status...")
        let status = try await apiClient.getReportStatus(requestId: reportRequestId)

        switch status {
        case .completed:
            Logger.ok("Report is ready for download")
        case .processing, .created:
            Logger.error("Report is not yet ready (status: \(status.rawValue))")
            Logger.info("Use 'appstore-analytics status \(reportRequestId) --watch' to monitor progress")
            throw NSError(domain: "DownloadCommand", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Report not ready for download"
            ])
        case .failed:
            Logger.error("Report generation failed")
            throw NSError(domain: "DownloadCommand", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Report generation failed"
            ])
        }

        // Fetch report instances
        Logger.info("Fetching report instances...")
        let instances = try await apiClient.getReportInstances(requestId: reportRequestId)

        guard !instances.isEmpty else {
            Logger.error("No report instances found")
            throw NSError(domain: "DownloadCommand", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "No report instances available"
            ])
        }

        Logger.ok("Found \(instances.count) report instance(s)")

        // Process each instance
        var allDownloadedPaths: [String] = []

        for (index, instance) in instances.enumerated() {
            Logger.info("\nProcessing instance \(index + 1)/\(instances.count): \(instance.id)")

            // Create instance-specific directory
            let instanceDir = "\(expandedOutputDir)/\(reportRequestId)/instance-\(instance.id)"

            // Fetch segments for this instance
            Logger.info("Fetching segments...")
            let segments = try await apiClient.getReportSegments(instanceId: instance.id)

            guard !segments.isEmpty else {
                Logger.error("No segments found for instance \(instance.id)")
                continue
            }

            Logger.ok("Found \(segments.count) segment(s)")

            // Download segments
            let downloader = CSVDownloader()
            let downloadedPaths = try await downloader.downloadSegments(
                segments: segments,
                outputDirectory: instanceDir,
                overwrite: overwrite
            )

            allDownloadedPaths.append(contentsOf: downloadedPaths)

            // Merge if requested and multiple segments
            if merge && downloadedPaths.count > 1 {
                let mergedPath = "\(instanceDir)/merged.csv"
                try await downloader.mergeCSVFiles(
                    paths: downloadedPaths,
                    outputPath: mergedPath
                )
                Logger.ok("Merged file: \(mergedPath)")
            }
        }

        // Summary
        Logger.success("\nDownload complete!")
        Logger.info("Total files downloaded: \(allDownloadedPaths.count)")
        Logger.info("Output directory: \(expandedOutputDir)/\(reportRequestId)")

        // Show file tree
        displayFileTree(directory: "\(expandedOutputDir)/\(reportRequestId)")
    }

    private static func displayFileTree(directory: String) {
        Logger.info("\nDownloaded files:")
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(atPath: directory) else {
            return
        }

        var fileCount = 0
        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(".csv") {
                let level = file.components(separatedBy: "/").count - 1
                let indent = String(repeating: "  ", count: level)
                Logger.info("\(indent)├── \(URL(fileURLWithPath: file).lastPathComponent)")
                fileCount += 1
            }
        }

        Logger.info("\nTotal CSV files: \(fileCount)")
    }
}
