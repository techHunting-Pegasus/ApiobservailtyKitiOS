//
//  observerdemoApp.swift
//  observerdemo
//
//  Created by Ishpreet singh on 06/10/26.
//

import SwiftUI
import APIObservabilityKit

@main
struct observerdemoApp: App {
    init() {
        APIObservability.shared.start(
            configuration:
                APIObservabilityConfiguration(
                    enabled: true,
                    logRequestHeaders: true,
                    logRequestBody: true,
                    logResponseHeaders: true,
                    logResponseBody: true,
                    maxBodySize: 10_000_000,
                    interval: 2,
//                    monitoringURL:
//                        URL(
//                            string:
//                            "https://api-observability-backend.onrender.com/api/v1/monitoring/logs"
//                        ),
////                    monitoringURL:
////                        URL(
////                            string:
////                            "http://10.0.1.43:3000/api/v1/monitoring/logs"
////                        ),
                    apikey: "obs_e35c2e027aee60948f8bd329613a454479be3c6d86aa3e0c78b4966ed800be7f",
                    appUserId: "usewf",
                    appUserEmail: "ew@gmail.com",
                    logintype:"guest",
                    deviceId:"wefvwrvr"
                    
                    
//                    ignoredHosts: [
//                        "your-api.com"
//                    ]
                )
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
