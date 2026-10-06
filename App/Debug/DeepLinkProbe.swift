import Foundation

/// CI only (DEBUG): a line per deep-link event in `Library/Caches/deeplink-log.txt`
/// inside the app's container, so the Simulator screenshots job can check that a
/// `simctl openurl` (cold and warm) really opened the title, not just screenshot it.
enum DeepLinkProbe {
    static func log(_ line: String) {
        #if DEBUG
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let url = dir.appendingPathComponent("deeplink-log.txt")
        let data = Data("\(line)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
        #endif
    }
}
