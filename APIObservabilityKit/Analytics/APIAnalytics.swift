//
//  APIAnalytics.swift
//  APIObservabilityKit
//
//  Firebase-style product analytics. Usage:
//
//      APIAnalytics.shared.start(configuration: .init(apiKey: "obs_xxx", debug: true))
//      APIAnalytics.shared.logEvent("add_to_cart", parameters: ["sku": "A1"])
//      APIAnalytics.shared.setDebugEnabled(false)
//
//  UIKit screens are tracked automatically; SwiftUI screens use `.trackScreen("Home")`.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

public final class APIAnalytics: @unchecked Sendable {

    public static let shared = APIAnalytics()

    private enum EventType: String {
        case custom
        case screenView = "screen_view"
        case session
    }

    /// Device and install details, read once at start.
    private struct Context {
        let anonymousId: String
        let debugDevice: AnalyticsBatch.DebugDevice
        let appVersion: String
        let iosVersion: String
        let deviceModel: String
    }

    // All mutable state is only accessed on `queue`.
    private let queue = DispatchQueue(label: "com.apiobservability.analytics")
    private var configuration: APIAnalyticsConfiguration?
    private var context: Context?
    private var debug = false
    private lazy var store = AnalyticsEventStore()
    private let uploader = AnalyticsUploader()
    private var isUploading = false
    private var flushTimer: DispatchSourceTimer?
    private var sessionId = AnalyticsFormat.newId()
    private var backgroundedAt: Date?
    private var lastScreen: (name: String, date: Date)?

    private init() {}

    // MARK: - Public API

    /// Starts analytics. Call once at launch. Later calls are ignored.
    @MainActor
    public func start(configuration: APIAnalyticsConfiguration) {
        let context = Context(
            anonymousId: Self.persistentId(forKey: "anonymousId"),
            debugDevice: .init(
                debugDeviceId: Self.persistentId(forKey: "debugDeviceId"),
                name: configuration.debugDeviceName ?? APIObservabilityDeviceInfo.deviceName
            ),
            appVersion: APIObservabilityDeviceInfo.appVersion,
            iosVersion: APIObservabilityDeviceInfo.iosVersion,
            deviceModel: APIObservabilityDeviceInfo.modelIdentifier
        )

        let alreadyStarted = queue.sync { () -> Bool in
            guard self.configuration == nil else { return true }
            self.configuration = configuration
            self.context = context
            self.debug = configuration.debug
            return false
        }
        guard !alreadyStarted else { return }

        queue.async {
            self.startFlushTimer(interval: configuration.flushInterval)
            self.enqueue("session_start", type: .session)
        }

        #if canImport(UIKit)
        observeAppLifecycle()
        if configuration.autoTrackScreens {
            UIViewController.enableAnalyticsScreenTracking()
        }
        #endif
    }

    /// Logs a custom event. Names must start with a letter and contain only letters,
    /// digits and underscores (max 40). Supported values: String, Int, Double, Bool.
    public func logEvent(_ name: String, parameters: [String: Any] = [:]) {
        guard Self.isValidName(name) else {
            print("APIAnalytics: invalid event name \"\(name)\", event dropped")
            return
        }
        let properties = Self.properties(from: parameters)
        queue.async { self.enqueue(name, type: .custom, properties: properties) }
    }

    /// Logs a `screen_view`. Called automatically for UIKit and by `.trackScreen(_:)`.
    public func logScreen(_ name: String, screenClass: String? = nil) {
        queue.async {
            // The same screen reported twice in a row (e.g. by UIKit and SwiftUI) counts once.
            if let last = self.lastScreen, last.name == name, Date().timeIntervalSince(last.date) < 1 {
                return
            }
            self.lastScreen = (name, Date())
            self.enqueue("screen_view", type: .screenView, properties: [
                "screen_name": .string(name),
                "screen_class": .string(screenClass ?? name),
            ])
        }
    }

    /// `true`: send every event immediately and show it in the dashboard's live debug view.
    /// `false`: batch events by `batchSize` and `flushInterval`.
    public func setDebugEnabled(_ enabled: Bool) {
        queue.async {
            self.debug = enabled
            self.flush(force: false)
        }
    }

    public var isDebugEnabled: Bool {
        queue.sync { debug }
    }

    /// Uploads all pending events now.
    public func flush() {
        queue.async { self.flush(force: true) }
    }

    // MARK: - Queue

    private func enqueue(
        _ name: String,
        type: EventType,
        properties: [String: AnalyticsValue] = [:]
    ) {
        guard let context else {
            print("APIAnalytics: call start(configuration:) before logging \"\(name)\"")
            return
        }
        let event = AnalyticsEvent(
            eventId: AnalyticsFormat.newId(),
            name: name,
            type: type.rawValue,
            properties: properties,
            timestamp: AnalyticsFormat.timestamp(),
            sessionId: sessionId,
            anonymousId: context.anonymousId,
            platform: "ios",
            appVersion: context.appVersion,
            iosVersion: context.iosVersion,
            deviceModel: context.deviceModel
        )
        store.append(PendingAnalyticsEvent(event: event, debug: debug))
        if debug {
            print("APIAnalytics [debug]: \(name) \(properties)")
        }
        flush(force: false)
    }

    /// Uploads the oldest pending events, one request at a time. Without `force`,
    /// only debug events or a full batch are sent; the timer sends the rest.
    private func flush(force: Bool) {
        guard
            let configuration, let context, !isUploading,
            let first = store.events.first,
            force || first.debug || store.events.count >= configuration.batchSize
        else {
            return
        }

        let events = store.events
            .prefix { $0.debug == first.debug }
            .prefix(configuration.batchSize)
            .map(\.event)
        let batch = AnalyticsBatch(
            batchId: AnalyticsFormat.newId(),
            sentAt: AnalyticsFormat.timestamp(),
            debug: first.debug,
            debugDevice: first.debug ? context.debugDevice : nil,
            events: events
        )

        isUploading = true
        uploader.send(batch, to: configuration.endpoint, apiKey: configuration.apiKey) { outcome in
            self.queue.async {
                self.isUploading = false
                guard outcome == .done else { return } // The next timer tick retries.
                self.store.remove(eventIds: Set(events.map(\.eventId)))
                self.flush(force: force)
            }
        }
    }

    private func startFlushTimer(interval: TimeInterval) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { self.flush(force: true) }
        timer.resume()
        flushTimer = timer
    }

    // MARK: - Session

    #if canImport(UIKit)
    private func observeAppLifecycle() {
        let center = NotificationCenter.default

        center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil
        ) { _ in
            self.queue.async {
                self.backgroundedAt = Date()
                self.flush(force: true)
            }
        }

        center.addObserver(
            forName: UIApplication.willEnterForegroundNotification, object: nil, queue: nil
        ) { _ in
            self.queue.async {
                guard let backgroundedAt = self.backgroundedAt, let configuration = self.configuration else {
                    return
                }
                self.backgroundedAt = nil
                if Date().timeIntervalSince(backgroundedAt) >= configuration.sessionTimeout {
                    self.sessionId = AnalyticsFormat.newId()
                    self.enqueue("session_start", type: .session)
                }
            }
        }
    }
    #endif

    // MARK: - Helpers

    private static func persistentId(forKey key: String) -> String {
        let defaultsKey = "com.apiobservability.analytics.\(key)"
        if let id = UserDefaults.standard.string(forKey: defaultsKey) {
            return id
        }
        let id = AnalyticsFormat.newId()
        UserDefaults.standard.set(id, forKey: defaultsKey)
        return id
    }

    private static func isValidName(_ name: String) -> Bool {
        name.range(of: "^[A-Za-z][A-Za-z0-9_]{0,39}$", options: .regularExpression) != nil
    }

    private static func properties(from parameters: [String: Any]) -> [String: AnalyticsValue] {
        var properties: [String: AnalyticsValue] = [:]
        for (key, value) in parameters {
            guard isValidName(key), let value = AnalyticsValue(value) else {
                print("APIAnalytics: parameter \"\(key)\" dropped (invalid name or unsupported type)")
                continue
            }
            properties[key] = value
        }
        return properties
    }
}
