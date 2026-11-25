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

    /// Hardware identifier such as "iPhone15,2" (`deviceModel` only says "iPhone").
    static var modelIdentifier: String {
        if let simulatorModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatorModel
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    static var deviceName: String {
        UIDevice.current.name
    }

    static var timezone: String {
        TimeZone.current.identifier
    }

    static var country: String? {
        Locale.current.region?.identifier
    }
}
