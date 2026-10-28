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
        startAutomaticUpload()

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
            pendingLogCount >= configuration.batchSize
        else {
            return
        }

        uploadPendingLogs(pendingLogCount: pendingLogCount)
    }

    private func uploadPendingLogs(pendingLogCount: Int?) {
        let url = configuration?.monitoringURL
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
