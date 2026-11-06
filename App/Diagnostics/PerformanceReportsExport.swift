import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// The saved performance reports as one JSON file, built when it is shared:
/// the app version, device and system, then every report as MetricKit wrote it.
struct PerformanceReportsExport: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { export in
            SentTransferredFile(try export.write())
        }
        .suggestedFileName("fusionha-performance-reports.json")
    }

    func write() throws -> URL {
        let reports: [[String: Any]] = PerformanceReports.files().compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let payload = try? JSONSerialization.jsonObject(with: data) else { return nil }
            return [
                "file": url.lastPathComponent,
                "received": PerformanceReports.modified(url).formatted(.iso8601),
                "payload": payload,
            ]
        }
        let body: [String: Any] = [
            "app": Bundle.main.appVersion,
            "bundle": Bundle.main.bundleIdentifier ?? "?",
            "device": Self.deviceModel,
            "system": "iOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "created": Date().formatted(.iso8601),
            "reports": reports,
        ]
        let data = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys])
        let url = FileManager.default.temporaryDirectory.appending(path: "fusionha-performance-reports.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// The hardware identifier (e.g. "iPhone18,3"), which names the model exactly.
    private static var deviceModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
