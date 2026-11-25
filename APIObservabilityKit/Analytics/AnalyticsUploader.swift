//
//  AnalyticsUploader.swift
//  APIObservabilityKit
//

import Foundation

/// Sends one batch to the analytics endpoint.
struct AnalyticsUploader {

    enum Outcome {
        /// Accepted (2xx), or permanently rejected (4xx): remove the events.
        case done
        /// Network error, timeout, 429 or 5xx: keep the events and retry on a later flush.
        case retryLater
    }

    // Like the monitoring uploader: no protocol classes, so APIObservability never
    // captures the SDK's own analytics requests.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = []
        return URLSession(configuration: configuration)
    }()

    func send(
        _ batch: AnalyticsBatch,
        to endpoint: URL,
        apiKey: String,
        completion: @escaping (Outcome) -> Void
    ) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        do {
            request.httpBody = try JSONEncoder().encode(batch)
        } catch {
            print("APIAnalytics: could not encode batch: \(error.localizedDescription)")
            completion(.done)
            return
        }

        Self.session.dataTask(with: request) { _, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch status {
            case 200..<300:
                completion(.done)
            case 400..<500 where status != 408 && status != 429:
                print("APIAnalytics: batch rejected with HTTP \(status), events dropped")
                completion(.done)
            default:
                print("APIAnalytics: upload failed (\(error?.localizedDescription ?? "HTTP \(status)")), will retry")
                completion(.retryLater)
            }
        }.resume()
    }
}
