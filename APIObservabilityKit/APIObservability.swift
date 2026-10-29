//
//  APIObservability.swift
//  APIObservabilityKit
//
//  Created by Ishpreet singh on 06/10/26.
//

import Foundation

public final class APIObservability {

    public static let shared =
        APIObservability()

    public private(set) var configuration:
        APIObservabilityConfiguration?
    
    private var flushTimer: Timer?

    private init() {}

    /// Call before creating each custom URLSession. Existing session settings and
    /// other protocol classes are preserved; the supplied configuration is copied.
    public func configureURLSessionConfiguration(
        _ configuration: URLSessionConfiguration
    ) -> URLSessionConfiguration {
        let configured = configuration.copy() as! URLSessionConfiguration
        var protocols = configured.protocolClasses ?? []
        protocols.removeAll { $0 == APIObservabilityURLProtocol.self }
        protocols.insert(APIObservabilityURLProtocol.self, at: 0)
        configured.protocolClasses = protocols
        return configured
    }

    func shouldCapture(_ request: URLRequest) -> Bool {
        guard let configuration, configuration.enabled,
              let url = request.url,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host?.lowercased(),
              !configuration.ignoredHosts.contains(host),
              configuration.includedHosts.isEmpty
                || configuration.includedHosts.contains(host)
        else {
            return false
        }

        // Never observe the SDK's own monitoring endpoint.
        let monitoringURL = configuration.monitoringURL
            ?? URL(string: "https://api-observability-backend.onrender.com/api/v1/monitoring/logs")!
        return !(url.scheme?.lowercased() == monitoringURL.scheme?.lowercased()
            && host == monitoringURL.host?.lowercased()
            && url.port == monitoringURL.port
            && url.path == monitoringURL.path)
    }

    public func start(
        configuration:
            APIObservabilityConfiguration =
                .init()
    ) {

        guard
            self.configuration == nil
        else {
            return
        }

        self.configuration =
            configuration

        URLProtocol.registerClass(
            APIObservabilityURLProtocol.self
        )
        if configuration.enabled && configuration.uploadLogs {
            startAutomaticUpload()
        }

        print(
            "APIObservability started"
        )
    }

    public func stop() {
        flushTimer?.invalidate()
               flushTimer = nil

        URLProtocol.unregisterClass(
            APIObservabilityURLProtocol.self
        )

        configuration = nil

        print(
            "APIObservability stopped"
        )
    }
    
    private func startAutomaticUpload() {

          

           flushTimer?.invalidate()

           flushTimer = Timer.scheduledTimer(
            withTimeInterval: configuration?.interval ?? 10.0,
               repeats: true
           ) { [weak self] _ in

               guard let self else {
                   return
               }

               self.uploadPendingLogs()
           }

           // Upload immediately once on startup
           uploadPendingLogs()
       }
    private func uploadPendingLogs() {
        uploadPendingLogs(pendingLogCount: nil)
    }

    func uploadPendingLogsIfBatchReady(pendingLogCount: Int) {
        guard
            let configuration,
            configuration.enabled,
            configuration.uploadLogs,
            pendingLogCount >= configuration.batchSize
        else {
            return
        }

        uploadPendingLogs(pendingLogCount: pendingLogCount)
    }

    private func uploadPendingLogs(pendingLogCount: Int?) {
        guard let configuration, configuration.enabled, configuration.uploadLogs else {
            return
        }
        let url = configuration.monitoringURL
            ?? URL(string: "https://api-observability-backend.onrender.com/api/v1/monitoring/logs")

        guard let monitoringURL = url else {
            print("Monitoring URL is invalid")
            return
        }

        APIObservabilityUploader.shared.uploadPendingLogs(
            monitoringURL: monitoringURL,
            pendingLogCount: pendingLogCount
        )
    }


    
}
