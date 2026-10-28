//
//  APIRequestLog.swift
//  APIObservabilityKit
//
//  Created by Ishpreet singh on 06/10/26.
//

import Foundation

public struct APIRequestLog: Identifiable, Codable, Sendable {

    public let id: UUID

    public let requestId: String

    public let url: String
    public let method: String

    public let requestHeaders: [String: String]?
    public let requestBody: String?

    public let responseStatus: Int?

    public let responseHeaders: [String: String]?
    public let responseBody: String?

    public let error: String?

    public let startedAt: Date
    public let completedAt: Date?

    public let durationMs: Int

    public let appVersion: String
    public let iosVersion: String
    public let deviceModel: String

    public let networkType: String?
    public let timezone: String
    public let country: String?
    public let bundleId: String
    public let appUserId: String?
    public let appUserEmail: String?
    public let logintype: String?
    public let deviceId: String?
 
    public init(
        id: UUID = UUID(),
        requestId: String,
        url: String,
        method: String,
        requestHeaders: [String: String]?,
        requestBody: String?,
        responseStatus: Int?,
        responseHeaders: [String: String]?,
        responseBody: String?,
        error: String?,
        startedAt: Date,
        completedAt: Date?,
        durationMs: Int,
        appVersion: String,
        iosVersion: String,
        deviceModel: String,
        networkType: String?,
        timezone: String,
        country: String?,
        bundleId: String,
        appUserId: String?,
        appUserEmail: String?,
        logintype: String?,
        deviceId:  String?,
    ) {
        self.id = id
        self.requestId = requestId
        self.url = url
        self.method = method
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.responseStatus = responseStatus
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.error = error
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.durationMs = durationMs
        self.appVersion = appVersion
        self.iosVersion = iosVersion
        self.deviceModel = deviceModel
        self.networkType = networkType
        self.timezone = timezone
        self.country = country
        self.bundleId = bundleId
        self.appUserId = appUserId
        self.appUserEmail = appUserEmail
        self.logintype  = logintype
        self.deviceId = deviceId
    }
}
