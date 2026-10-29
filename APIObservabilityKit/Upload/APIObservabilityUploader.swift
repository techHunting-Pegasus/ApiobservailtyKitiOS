//
//  APIObservabilityUploader.swift
//  APIObservabilityKit
//
//  Created by Ishpreet singh on 06/10/26.
//

import Foundation

final class APIObservabilityUploader {
    
    static let shared =
    APIObservabilityUploader()
    
    private lazy var session: URLSession = {
        
        let configuration =
        URLSessionConfiguration.ephemeral
        
        // Important:
        // Monitoring API khud monitor nahi honi chahiye.
        configuration.protocolClasses = []
        
        return URLSession(
            configuration: configuration
        )
    }()
    
    private var isUploading = false
    private var uploadRequested = false
    private var inFlightLogCount = 0
    private var monitoringURL: URL?
    
    private let queue =
    DispatchQueue(
        label: "com.apiobservability.uploader"
    )
    
    
    private init() {}
    
    func uploadPendingLogs(
        monitoringURL: URL,
        pendingLogCount: Int? = nil
    ) {
        
        queue.async { [weak self] in
            
            guard let self else {
                return
            }
            
            if let pendingLogCount {
                let batchSize =
                    APIObservability.shared.configuration?.batchSize ?? 20
                let waitingLogCount =
                    pendingLogCount - self.inFlightLogCount

                guard waitingLogCount >= batchSize else {
                    return
                }
            }

            self.monitoringURL = monitoringURL
            self.uploadRequested = true
            self.startNextUploadIfNeeded()
        }
    }

    private func startNextUploadIfNeeded() {
        guard
            !isUploading,
            uploadRequested,
            let configuration = APIObservability.shared.configuration,
            configuration.enabled,
            configuration.uploadLogs,
            let monitoringURL
        else {
            return
        }

        let batchSize =
            APIObservability.shared.configuration?.batchSize ?? 20
        let logs =
            APIObservabilityStore.shared.pendingLogs(limit: batchSize)

        guard !logs.isEmpty else {
            uploadRequested = false
            return
        }

        uploadRequested = false
        isUploading = true
        inFlightLogCount = logs.count

        upload(
            logs: logs,
            monitoringURL: monitoringURL
        )
    }
    
    private func upload(
        logs: [APIRequestLog],
        monitoringURL: URL
    ) {
        
        let dtoLogs =
        logs.map {
            APIRequestLogDTO(
                requestId: $0.requestId,
                url: $0.url,
                method: $0.method,
                requestHeaders:
                    $0.requestHeaders,
                requestBody:
                    $0.requestBody,
                responseStatus:
                    $0.responseStatus,
                responseHeaders:
                    $0.responseHeaders,
                responseBody:
                    $0.responseBody,
                error:
                    $0.error,
                startedAt:
                    $0.startedAt,
                completedAt:
                    $0.completedAt,
                durationMs:
                    $0.durationMs,
                appVersion:
                    $0.appVersion,
                iosVersion:
                    $0.iosVersion,
                deviceModel:
                    $0.deviceModel,
                networkType:
                    $0.networkType,
                timezone:
                    $0.timezone,
                country:
                    $0.country,
                bundleId:  $0.bundleId,
                appUserId: $0.appUserId,
                appUserEmail: $0.appUserEmail,
                logintype: $0.logintype,
                deviceId: $0.deviceId,
            )
        }
        
        let payload =
        ["logs": dtoLogs]
        
        var request =
        URLRequest(
            url: monitoringURL
        )
        
        request.httpMethod = "POST"
        
        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Content-Type"
        )
        request.setValue(
            APIObservability.shared.configuration?.apikey,
            forHTTPHeaderField:
                "X-API-Key"
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            request.httpBody = try encoder.encode(payload)
        } catch {
            
            finishUpload()
            
            return
        }
        
        
        session.dataTask(
            with: request
        ) { [weak self] _, response, error in

            // MARK: - Network Error
            
            guard error == nil else {
                print(
                    "APIObservability Upload Failed:",
                    error?.localizedDescription ?? "Unknown error"
                )
                self?.finishUpload()
                return
            }
            
            // MARK: - HTTP Response
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print(
                    "APIObservability Upload Failed: Invalid HTTP response"
                )
                self?.finishUpload()
                return
            }
            
            // MARK: - Status Code
            
            guard (200...299).contains(
                httpResponse.statusCode
            ) else {
                
                print(
                    "APIObservability Upload Failed. Status Code:",
                    httpResponse.statusCode
                )
                self?.finishUpload()
                return
            }
            
            // MARK: - Success
            
            print(
                "APIObservability Upload Successful. Status Code:",
                httpResponse.statusCode
            )
            
            APIObservabilityStore.shared.remove(
                requestIds: Set(
                    logs.map(\.requestId)
                )
            )
            self?.finishUpload(shouldDrain: true)

        }.resume()
        
        
    }
    
    private func finishUpload(shouldDrain: Bool = false) {
        
        queue.async { [weak self] in
            guard let self else {
                return
            }

            self.isUploading = false
            self.inFlightLogCount = 0

            if shouldDrain {
                let batchSize =
                    APIObservability.shared.configuration?.batchSize ?? 20
                let pendingLogs =
                    APIObservabilityStore.shared.pendingLogs(limit: batchSize)
                self.uploadRequested = self.uploadRequested
                    || pendingLogs.count == batchSize
            }

            self.startNextUploadIfNeeded()
        }
    }
}
