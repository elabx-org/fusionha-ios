import Foundation

// Settings › Quality › Quality Definitions, native (web `QualityDefinitionsPanel.tsx`):
// per-quality size limits in MB per runtime-minute, grouped by resolution, with a
// runtime preview in GB per file. `max == 0` means unlimited.

/// `QualityDefinitionRead`.
public struct QualityDefinitionRecord: Decodable, Sendable, Hashable, Identifiable {
    public let id: Int
    public let quality: String
    public let title: String
    public let mediaKind: String?
    public let minSize: Double
    public let maxSize: Double
    public let preferredSize: Double
}

/// A row's working window, MB/min. `max <= 0` is unlimited.
public struct QualitySizeRange: Hashable, Sendable {
    public var min: Double
    public var pref: Double
    public var max: Double
    public init(min: Double, pref: Double, max: Double) {
        self.min = min
        self.pref = pref
        self.max = max
    }
    public init(_ def: QualityDefinitionRecord) {
        self.init(min: def.minSize, pref: def.preferredSize, max: def.maxSize)
    }
    public var unlimited: Bool { max <= 0 }
}

public enum QualitySizeLimits {
    /// The slider axis maximum; larger stored values render clamped.
    public static let axisMax: Double = 280

    public enum Handle: Sendable { case min, pref, max }

    /// arr/TRaSH defaults (migrations 0024 + 0026), used by "Reset to defaults".
    public static let defaults: [String: QualitySizeRange] = {
        let table: [(String, Double, Double, Double)] = [
            ("SDTV", 0, 95, 100), ("HDTV_720P", 0, 95, 125), ("HDTV_1080P", 0, 95, 130),
            ("WEBDL_720P", 3, 95, 125), ("WEBDL_1080P", 4, 95, 130), ("WEBDL_2160P", 35, 95, 0),
            ("BLURAY_720P", 0, 95, 130), ("BLURAY_1080P", 0, 95, 155), ("BLURAY_2160P", 35, 95, 0),
            ("REMUX_1080P", 0, 95, 0), ("REMUX_2160P", 35, 95, 0), ("UNKNOWN", 0, 0, 0),
            ("WEBRIP_2160P", 35, 95, 0), ("WEBRIP_1080P", 4, 95, 130), ("WEBRIP_720P", 3, 95, 130),
            ("WEBRIP_480P", 2, 95, 100), ("WEBDL_480P", 2, 95, 100), ("HDTV_2160P", 35, 95, 199.9),
            ("BLURAY_576P", 2, 95, 100), ("BLURAY_480P", 2, 95, 100), ("DVD", 2, 95, 100),
            ("RAWHD", 4, 95, 0), ("BRDISK", 0, 95, 0), ("DVDR", 0, 95, 100), ("DVDSCR", 0, 95, 100),
            ("REGIONAL", 0, 95, 100), ("TELECINE", 0, 95, 100), ("TELESYNC", 0, 95, 100),
            ("CAM", 0, 95, 100), ("WORKPRINT", 0, 95, 100),
        ]
        var map: [String: QualitySizeRange] = [:]
        for (q, lo, pref, hi) in table { map[q] = QualitySizeRange(min: lo, pref: pref, max: hi) }
        return map
    }()

    public static let groupOrder = ["2160p", "1080p", "720p", "SD / other"]

    public static func group(of quality: String) -> String {
        if quality.contains("2160P") { return "2160p" }
        if quality.contains("1080P") || quality == "RAWHD" { return "1080p" }
        if quality.contains("720P") { return "720p" }
        return "SD / other"
    }

    /// Definitions sorted best-first and grouped by resolution (empty groups dropped).
    public static func grouped(_ defs: [QualityDefinitionRecord]) -> [(name: String, rows: [QualityDefinitionRecord])] {
        let index = Dictionary(uniqueKeysWithValues: QualityLadder.order.enumerated().map { ($1, $0) })
        let sorted = defs.sorted { (index[$0.quality] ?? 999) < (index[$1.quality] ?? 999) }
        return groupOrder.compactMap { name -> (name: String, rows: [QualityDefinitionRecord])? in
            let rows = sorted.filter { group(of: $0.quality) == name }
            return rows.isEmpty ? nil : (name, rows)
        }
    }

    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { Swift.min(hi, Swift.max(lo, v)) }

    /// Move one handle so min ≤ preferred ≤ max holds. Max at (near) the axis end is unlimited.
    public static func constrain(_ cur: QualitySizeRange, _ handle: Handle, _ raw: Double) -> QualitySizeRange {
        let v = clamp(raw.rounded(), 0, axisMax)
        var next = cur
        switch handle {
        case .min: next.min = clamp(v, 0, cur.pref)
        case .pref: next.pref = clamp(v, cur.min, cur.unlimited ? axisMax : cur.max)
        case .max: next.max = v >= axisMax - 2 ? 0 : Swift.max(v, cur.pref)
        }
        return next
    }

    /// Typed min: clamps into [0, preferred]; blank = 0.
    public static func typedMin(_ cur: QualitySizeRange, _ v: Double?) -> QualitySizeRange {
        var next = cur
        next.min = clamp((v ?? 0).rounded(), 0, cur.pref)
        return next
    }

    /// Typed max: blank or ≤ 0 = unlimited, else ≥ preferred. Not snapped to the axis.
    public static func typedMax(_ cur: QualitySizeRange, _ v: Double?) -> QualitySizeRange {
        var next = cur
        if let v, v > 0 { next.max = Swift.max(v.rounded(), cur.pref) } else { next.max = 0 }
        return next
    }

    /// GB a MB/min rate implies over `runtime` minutes (binary GB).
    public static func gigabytes(_ mbPerMin: Double, runtime: Int) -> Double { mbPerMin * Double(runtime) / 1024 }

    /// Sub-1 GB values render in MB.
    public static func formatGB(_ v: Double) -> String {
        v < 1 ? String(format: "%.0f MB", v * 1024) : String(format: "%.2f GB", v)
    }

    /// `"1.32 GB – 4.39 GB"`, or `"… – unlimited"`.
    public static func fileSizeLine(_ r: QualitySizeRange, runtime: Int) -> String {
        let lo = formatGB(gigabytes(r.min, runtime: runtime))
        return r.unlimited ? "\(lo) – unlimited" : "\(lo) – \(formatGB(gigabytes(r.max, runtime: runtime)))"
    }
}

extension APIClient {
    /// The shared (kindless) definitions, one per quality.
    public func qualityDefinitionRecords() async throws -> [QualityDefinitionRecord] {
        try await get("/api/v1/qualitydefinitions")
    }

    /// `PUT /api/v1/qualitydefinitions/{id}` with the web's body.
    public func updateQualityDefinition(_ def: QualityDefinitionRecord, _ range: QualitySizeRange) async throws {
        try await sendJSON("PUT", "/api/v1/qualitydefinitions/\(def.id)", .object([
            "quality": .string(def.quality), "title": .string(def.title),
            "min_size": .double(range.min), "preferred_size": .double(range.pref), "max_size": .double(range.max),
        ]))
    }
}
