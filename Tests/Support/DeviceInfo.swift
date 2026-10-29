// The networking regression executable runs on macOS without UIKit.
import Foundation

enum APIObservabilityDeviceInfo {
    static let bundleId = "networking.regression.tests"
    static let appVersion = "1.0"
    static let iosVersion = "test"
    static let deviceModel = "test"
    static let timezone = "UTC"
    static let country: String? = "IN"
}
