// Models.swift
//
// Minimal OpenAPI model support (no HTTP client types).
//

import Foundation

protocol JSONEncodable {
    func encodeToJSON() -> Any
}

open class CodableHelper: @unchecked Sendable {
    nonisolated(unsafe) private static var customDateFormatter: DateFormatter?
    private static let defaultDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        return formatter
    }()

    public static var dateFormatter: DateFormatter {
        get { customDateFormatter ?? defaultDateFormatter }
        set { customDateFormatter = newValue }
    }

    public static let jsonDecoder = JSONDecoder()

    public static let jsonEncoder = JSONEncoder()

    open class func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable {
        try jsonDecoder.decode(type, from: data)
    }

    open class func encode<T>(_ value: T) throws -> Data where T: Encodable {
        try jsonEncoder.encode(value)
    }
}
