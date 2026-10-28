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
    
    private let queue =
    DispatchQueue(
        label: "com.apiobservability.uploader"
    )
    let configuration =
    APIObservability.shared.configuration
    
    
    private init() {}
    
    func uploadPendingLogs(
        monitoringURL: URL
    ) {
        
        queue.async { [weak self] in
            
            guard let self else {
                return
            }
            
            guard !self.isUploading else {
                return
            }
            
            let logs =
            APIObservabilityStore.shared
                .pendingLogs()
            
            guard !logs.isEmpty else {
                return
            }
            
            self.isUploading = true
            
            self.upload(
                logs: logs,
                monitoringURL: monitoringURL
            )
        }
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
            configuration?.apikey,
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
        ) { [weak self] data, response, error in
            
            defer {
                self?.finishUpload()
            }
            
            // MARK: - Network Error
            
            guard error == nil else {
                print(
                    "APIObservability Upload Failed:",
                    error?.localizedDescription ?? "Unknown error"
                )
                return
            }
            
            // MARK: - HTTP Response
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print(
                    "APIObservability Upload Failed: Invalid HTTP response"
                )
                return
            }
            
            // MARK: - Response Body
            
            if let data {
                if let responseString = String(
                    data: data,
                    encoding: .utf8
                ) {
                    print(
                        "APIObservability Upload Response:",
                        responseString
                    )
                }
            }
            
            // MARK: - Status Code
            
            guard (200...299).contains(
                httpResponse.statusCode
            ) else {
                
                print(
                    "APIObservability Upload Failed. Status Code:",
                    httpResponse.statusCode
                )
                
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
            
        }.resume()
        
        
    }
    
    private func finishUpload() {
        
        queue.async { [weak self] in
            self?.isUploading = false
        }
    }
}
