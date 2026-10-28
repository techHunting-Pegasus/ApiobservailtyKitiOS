//
//  APIRequestLogDTO.swift
//  APIObservabilityKit
//
//  Created by Ishpreet singh on 06/10/26.
//

import Foundation

struct APIRequestLogDTO: Codable, Sendable {

    let requestId: String

    let url: String
    let method: String

    let requestHeaders: [String: String]?
    let requestBody: String?

    let responseStatus: Int?

    let responseHeaders: [String: String]?
    let responseBody: String?

    let error: String?

    let startedAt: Date
    let completedAt: Date?

    let durationMs: Int

    let appVersion: String
    let iosVersion: String
    let deviceModel: String

    let networkType: String?
    let timezone: String
    let country: String?
    let bundleId:String?
    let appUserId: String?
    let appUserEmail: String?
    let logintype: String?
    let deviceId: String?
}
