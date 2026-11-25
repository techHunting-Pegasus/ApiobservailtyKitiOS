//
//  AnalyticsEventStore.swift
//  APIObservabilityKit
//

import Foundation

/// Pending events, saved to disk so they survive an app kill.
/// Not thread-safe: only `APIAnalytics` uses it, on its serial queue.
final class AnalyticsEventStore {

    private static let maxEvents = 1_000

    private(set) var events: [PendingAnalyticsEvent]
    private let fileURL: URL

    init(fileURL: URL = AnalyticsEventStore.defaultFileURL) {
        self.fileURL = fileURL
        let data = try? Data(contentsOf: fileURL)
        events = data.flatMap { try? JSONDecoder().decode([PendingAnalyticsEvent].self, from: $0) } ?? []
    }

    func append(_ event: PendingAnalyticsEvent) {
        events.append(event)
        // Drop the oldest events when the device has been offline for a long time.
        if events.count > Self.maxEvents {
            events.removeFirst(events.count - Self.maxEvents)
        }
        save()
    }

    func remove(eventIds: Set<String>) {
        events.removeAll { eventIds.contains($0.event.eventId) }
        save()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(events).write(to: fileURL, options: .atomic)
        } catch {
            print("APIAnalytics: could not save pending events: \(error.localizedDescription)")
        }
    }

    static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("APIObservability", isDirectory: true)
            .appendingPathComponent("analytics-events.json")
    }
}
