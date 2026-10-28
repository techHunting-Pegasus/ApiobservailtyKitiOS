//
//  APIObservabilityDeviceInfo.swift
//  APIObservabilityKit
//
//  Created by Ishpreet singh on 06/10/26.
//

import Foundation
import UIKit

enum APIObservabilityDeviceInfo {
    static var bundleId: String {
           Bundle.main.bundleIdentifier ?? "unknown"
       }

    static var appVersion: String {

        Bundle.main.object(
            forInfoDictionaryKey:
                "CFBundleShortVersionString"
        ) as? String ?? "Unknown"
    }

    static var iosVersion: String {
        UIDevice.current.systemVersion
    }

    static var deviceModel: String {
        UIDevice.current.model
    }

    static var timezone: String {
        TimeZone.current.identifier
    }

    static var country: String? {
        Locale.current.region?.identifier
    }
}
