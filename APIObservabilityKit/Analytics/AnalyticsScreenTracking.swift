//
//  AnalyticsScreenTracking.swift
//  APIObservabilityKit
//
//  UIKit: automatic `screen_view` from `viewDidAppear`.
//  SwiftUI: there is no public screen lifecycle, so add `.trackScreen("Name")` to each screen.
//

#if canImport(UIKit)
import SwiftUI
import UIKit

/// Adopt in a UIKit view controller to rename its screen, or return nil to skip it.
public protocol AnalyticsScreenNaming {
    var analyticsScreenName: String? { get }
}

public extension View {
    /// Logs a `screen_view` named `name` each time this view appears.
    func trackScreen(_ name: String) -> some View {
        onAppear { APIAnalytics.shared.logScreen(name) }
    }
}

extension UIViewController {

    /// Swaps in `analytics_viewDidAppear` once for every view controller.
    static func enableAnalyticsScreenTracking() {
        _ = swizzleViewDidAppear
    }

    private static let swizzleViewDidAppear: Void = {
        guard
            let original = class_getInstanceMethod(UIViewController.self, #selector(viewDidAppear(_:))),
            let replacement = class_getInstanceMethod(UIViewController.self, #selector(analytics_viewDidAppear(_:)))
        else {
            return
        }
        method_exchangeImplementations(original, replacement)
    }()

    // After the exchange, this name points to the original `viewDidAppear`.
    @objc private func analytics_viewDidAppear(_ animated: Bool) {
        analytics_viewDidAppear(animated)
        if let name = automaticScreenName {
            APIAnalytics.shared.logScreen(name, screenClass: String(describing: type(of: self)))
        }
    }

    /// The app's own screens only: no containers, no Apple-internal controllers and
    /// no generic SwiftUI hosting controllers (their names are not meaningful).
    private var automaticScreenName: String? {
        if let named = self as? AnalyticsScreenNaming {
            return named.analyticsScreenName
        }
        if self is UINavigationController || self is UITabBarController
            || self is UIPageViewController || self is UISplitViewController {
            return nil
        }
        let className = String(describing: type(of: self))
        let bundlePath = Bundle(for: type(of: self)).bundlePath
        guard
            !className.contains("<"),
            !className.hasPrefix("_"),
            !bundlePath.contains("/System/Library/"),
            !bundlePath.hasPrefix("/usr/lib")
        else {
            return nil
        }
        return className
    }
}
#endif
