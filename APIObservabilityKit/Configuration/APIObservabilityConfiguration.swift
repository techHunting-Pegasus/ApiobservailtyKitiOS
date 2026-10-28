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
    
    public let maxBodySize: Int
    public let interval: Double
    

    public let monitoringURL: URL?
    public let apikey: String

    public let ignoredHosts: Set<String>

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
    ) {
        self.enabled = enabled
        self.logRequestHeaders = logRequestHeaders
        self.logRequestBody = logRequestBody
        self.logResponseHeaders = logResponseHeaders
        self.logResponseBody = logResponseBody
        self.maxBodySize = maxBodySize
        self.interval = interval
        self.monitoringURL = monitoringURL
        self.ignoredHosts = ignoredHosts
        self.sensitiveHeaders = sensitiveHeaders
        self.sensitiveBodyKeys = sensitiveBodyKeys
        self.uploadLogs = uploadLogs
        self.apikey = apikey
        self.appUserId = appUserId
        self.appUserEmail = appUserEmail
        self.logintype = logintype
        self.deviceId = deviceId
    }
}
