//
//  APIObservabilityStore.swift
//  APIObservabilityKit
//
//  Created by Ishpreet singh on 06/10/26.
//

import Foundation

final class APIObservabilityStore {

    static let shared = APIObservabilityStore()

    private let queue =
        DispatchQueue(
            label: "com.apiobservability.store",
            qos: .utility
        )

    private var logs: [APIRequestLog] = []

    private init() {}

    func save(
        _ log: APIRequestLog
    ) {

        queue.async { [weak self] in

            self?.logs.append(log)

            print(
                "APIObservability: stored log \(log.requestId)"
            )
        }
    }

    func pendingLogs() -> [APIRequestLog] {

        queue.sync {
            logs
        }
    }

    func remove(
        requestIds: Set<String>
    ) {

        queue.async { [weak self] in

            self?.logs.removeAll {
                requestIds.contains(
                    $0.requestId
                )
            }
        }
    }

    func removeAll() {

        queue.async { [weak self] in
            self?.logs.removeAll()
        }
    }
}
