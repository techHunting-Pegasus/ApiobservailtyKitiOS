//
//  AnalyticsModels.swift
//  APIObservabilityKit
//
//  Wire format of POST /api/v1/analytics/events.
//

import Foundation

/// A property value the backend accepts: string, integer, decimal or boolean.
enum AnalyticsValue: Codable, Equatable, CustomStringConvertible {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    /// Returns nil for unsupported types (arrays, dictionaries, dates, ...).
    init?(_ value: Any) {
        switch value {
        case let value as Bool: self = .bool(value)
        case let value as Int: self = .int(value)
        case let value as Double: self = .double(value)
        case let value as Float: self = .double(Double(value))
        case let value as String: self = .string(value)
        default: return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Int.self) { self = .int(value) }
        else if let value = try? container.decode(Double.self) { self = .double(value) }
        else { self = .string(try container.decode(String.self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        }
    }

    var description: String {
        switch self {
        case .string(let value): return "\"\(value)\""
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .bool(let value): return String(value)
        }
    }
}

struct AnalyticsEvent: Codable {
    let eventId: String
    let name: String
    let type: String
    let properties: [String: AnalyticsValue]
    let timestamp: String
    let sessionId: String
    let anonymousId: String
    let platform: String
    let appVersion: String
    let iosVersion: String
    let deviceModel: String
}

struct AnalyticsBatch: Encodable {
    struct DebugDevice: Encodable {
        let debugDeviceId: String
        let name: String
    }

    let batchId: String
    let sentAt: String
    let debug: Bool
    let debugDevice: DebugDevice?
    let events: [AnalyticsEvent]
}

/// An event waiting for upload. `debug` is the mode it was logged in, so events
/// logged before and after `setDebugEnabled` are never mixed in one batch.
struct PendingAnalyticsEvent: Codable {
    let event: AnalyticsEvent
    let debug: Bool
}

enum AnalyticsFormat {
    /// "2026-11-25T10:00:00.000Z"
    static func timestamp(_ date: Date = Date()) -> String {
        formatter.string(from: date)
    }

    static func newId() -> String {
        UUID().uuidString.lowercased()
    }

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
