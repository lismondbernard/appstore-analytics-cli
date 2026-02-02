import XCTest
import Foundation
import Compression
@testable import AppStoreAnalyticsCLI

final class CSVDownloaderTests: XCTestCase {

    // MARK: - decompressGzipIfNeeded

    func testDecompressGzipData() throws {
        let original = "Install Day\tApp Name\tInstalls\n2026-01-01\tMyApp\t42\n"
        let originalData = Data(original.utf8)

        // Gzip compress the data
        let gzipped = try gzipCompress(originalData)

        // Verify it has gzip magic bytes
        XCTAssertEqual(gzipped[0], 0x1f)
        XCTAssertEqual(gzipped[1], 0x8b)

        let decompressed = CSVDownloader.decompressGzipIfNeeded(gzipped)
        let result = String(data: decompressed, encoding: .utf8)

        XCTAssertEqual(result, original)
    }

    func testNonGzipDataPassesThrough() {
        let csv = "header1,header2\nval1,val2\n"
        let data = Data(csv.utf8)

        let result = CSVDownloader.decompressGzipIfNeeded(data)

        XCTAssertEqual(result, data)
    }

    func testEmptyDataPassesThrough() {
        let data = Data()
        let result = CSVDownloader.decompressGzipIfNeeded(data)
        XCTAssertEqual(result, data)
    }

    func testSingleBytePassesThrough() {
        let data = Data([0x1f])
        let result = CSVDownloader.decompressGzipIfNeeded(data)
        XCTAssertEqual(result, data)
    }

    // MARK: - Helpers

    /// Compress data using gzip format
    private func gzipCompress(_ data: Data) throws -> Data {
        var result = Data()

        // Gzip header
        result.append(contentsOf: [
            0x1f, 0x8b, // magic
            0x08,       // compression method (deflate)
            0x00,       // flags
            0x00, 0x00, 0x00, 0x00, // mtime
            0x00,       // extra flags
            0xff        // OS (unknown)
        ])

        // Compress with zlib raw deflate
        let srcArray = [UInt8](data)
        let bufferSize = max(data.count * 2, 128)
        let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { dstBuffer.deallocate() }

        var stream = compression_stream(dst_ptr: dstBuffer, dst_size: bufferSize, src_ptr: UnsafePointer(dstBuffer), src_size: 0, state: nil)
        let initStatus = compression_stream_init(&stream, COMPRESSION_STREAM_ENCODE, COMPRESSION_ZLIB)
        guard initStatus == COMPRESSION_STATUS_OK else {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "compression_stream_init failed"])
        }
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
                if status == COMPRESSION_STATUS_ERROR { break }
            }
        }

        // Gzip trailer: CRC32 + original size
        let crc = crc32(data)
        let size = UInt32(data.count)
        result.append(contentsOf: withUnsafeBytes(of: crc.littleEndian) { Array($0) })
        result.append(contentsOf: withUnsafeBytes(of: size.littleEndian) { Array($0) })

        return result
    }

    /// Simple CRC32 implementation for gzip trailer
    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ (crc & 1 != 0 ? 0xEDB88320 : 0)
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}
