import Foundation

/// A one-file `multipart/form-data` body (the browser's `FormData` with a
/// single `file` field), for uploads such as the Letterboxd export.
struct MultipartForm {
    let boundary = "fusionha-\(UUID().uuidString)"

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    func body(field: String, filename: String, mimeType: String, data: Data) -> Data {
        // A quote or line break in the name would end the header early.
        let safeName = filename.filter { $0 != "\"" && $0 != "\r" && $0 != "\n" }
        var out = Data()
        out.append(Data("--\(boundary)\r\n".utf8))
        out.append(Data("Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(safeName)\"\r\n".utf8))
        out.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        out.append(data)
        out.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return out
    }
}
