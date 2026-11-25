//
//  APIAnalyticsConfiguration.swift
//  APIObservabilityKit
//

import Foundation

/// Settings for `APIAnalytics`. Every value has a sensible default except `apiKey`.
public struct APIAnalyticsConfiguration: Sendable {

    /// Sent as the `X-API-Key` header.
    public var apiKey: String

    /// Analytics ingestion endpoint.
    public var endpoint: URL

    /// `true`: each event is sent immediately and shown in the dashboard's live debug view.
    /// `false`: events are batched by `batchSize` and `flushInterval`.
    /// Can be changed later with `APIAnalytics.shared.setDebugEnabled(_:)`.
    public var debug: Bool

    /// Device name shown in the dashboard's debug view. Defaults to the device name
    /// (iOS 16+ reports a generic "iPhone", so set this to tell test devices apart).
    public var debugDeviceName: String?

    /// Seconds between automatic uploads of pending events.
    public var flushInterval: TimeInterval

    /// Upload as soon as this many events are pending, and the maximum events per request.
    public var batchSize: Int

    /// Automatically log `screen_view` for UIKit view controllers.
    /// SwiftUI screens use the `.trackScreen(_:)` modifier.
    public var autoTrackScreens: Bool

    /// A new session starts when the app returns after this many seconds in the background.
    public var sessionTimeout: TimeInterval

    public init(
        apiKey: String,
        endpoint: URL = URL(string: "https://api-observability-backend.onrender.com/api/v1/analytics/events")!,
        debug: Bool = false,
        debugDeviceName: String? = nil,
        flushInterval: TimeInterval = 30,
        batchSize: Int = 20,
        autoTrackScreens: Bool = true,
        sessionTimeout: TimeInterval = 30 * 60
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.debug = debug
        self.debugDeviceName = debugDeviceName
        self.flushInterval = max(1, flushInterval)
        self.batchSize = max(1, batchSize)
        self.autoTrackScreens = autoTrackScreens
        self.sessionTimeout = sessionTimeout
    }
}
