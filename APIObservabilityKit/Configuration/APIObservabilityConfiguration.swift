    //
//  APIObservabilityConfiguration.swift
//  APIObservabilityKit
//
//  Created by Ishpreet singh on 06/10/26.
//

import Foundation

public struct APIObservabilityConfiguration: Sendable {

    public let enabled: Bool
    
    // Console logging only
    public let logRequestHeaders: Bool
    public let logRequestBody: Bool
    public let logResponseHeaders: Bool
    public let logResponseBody: Bool
    
    // Monitoring upload
    public let uploadLogs: Bool
    public let uploadRequestHeaders: Bool
    public let uploadRequestBody: Bool
    public let uploadResponseHeaders: Bool
    public let uploadResponseBody: Bool
    
    public let maxBodySize: Int
    public let interval: Double
    public let batchSize: Int
    

    public let monitoringURL: URL?
    public let apikey: String

    public let ignoredHosts: Set<String>

    /// Exact host names to capture. An empty set captures all non-ignored hosts.
    public let includedHosts: Set<String>

    public let sensitiveHeaders: Set<String>

    public let sensitiveBodyKeys: Set<String>
    public let appUserId: String?
    public let appUserEmail: String?
    public let logintype: String?
    public let deviceId: String?

    public init(
        enabled: Bool = true,
        // Only console
        logRequestHeaders: Bool = true,
        logRequestBody: Bool = true,
        logResponseHeaders: Bool = true,
        logResponseBody: Bool = true,
        
        // Upload still ON
        uploadLogs: Bool = true,
        maxBodySize: Int = 1_000_000,
        interval: Double = 10.0,
        batchSize: Int = 20,
        monitoringURL: URL? = nil,
        apikey: String = "",
        ignoredHosts: Set<String> = [],
        sensitiveHeaders: Set<String> = [
//            "authorization",
//            "cookie",
//            "set-cookie",
//            "x-api-key",
//            "api-key"
        ],
        sensitiveBodyKeys: Set<String> = [
//            "password",
//            "token",
//            "access_token",
//            "refresh_token",
//            "authorization",
//            "api_key",
//            "apikey",
//            "secret"
        ],
        appUserId:String? = nil,
        appUserEmail:String? = nil,
        logintype:String? = nil,
        deviceId:String? = nil,
        includedHosts: Set<String> = [],
        uploadRequestHeaders: Bool = true,
        uploadRequestBody: Bool = true,
        uploadResponseHeaders: Bool = true,
        uploadResponseBody: Bool = true,
    ) {
        self.enabled = enabled
        self.logRequestHeaders = logRequestHeaders
        self.logRequestBody = logRequestBody
        self.logResponseHeaders = logResponseHeaders
        self.logResponseBody = logResponseBody
        self.maxBodySize = max(0, maxBodySize)
        self.interval = interval
        self.batchSize = max(1, batchSize)
        self.monitoringURL = monitoringURL
        self.ignoredHosts = Set(ignoredHosts.map { $0.lowercased() })
        self.includedHosts = Set(includedHosts.map { $0.lowercased() })
        self.sensitiveHeaders = Set(sensitiveHeaders.map { $0.lowercased() })
        self.sensitiveBodyKeys = Set(sensitiveBodyKeys.map { $0.lowercased() })
        self.uploadLogs = uploadLogs
        self.uploadRequestHeaders = uploadRequestHeaders
        self.uploadRequestBody = uploadRequestBody
        self.uploadResponseHeaders = uploadResponseHeaders
        self.uploadResponseBody = uploadResponseBody
        self.apikey = apikey
        self.appUserId = appUserId
        self.appUserEmail = appUserEmail
        self.logintype = logintype
        self.deviceId = deviceId
    }
}
