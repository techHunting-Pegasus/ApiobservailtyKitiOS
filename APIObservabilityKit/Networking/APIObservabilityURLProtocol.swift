//
//  APIObservabilityURLProtocol.swift
//  APIObservabilityKit
//
//  Created by Ishpreet singh on 06/10/26.
//

import Foundation

final class APIObservabilityURLProtocol: URLProtocol, @unchecked Sendable {

    private static let handledKey =
        "APIObservabilityURLProtocolHandled"

    private var dataTask: URLSessionDataTask?

    private var session: URLSession?

    private var startDate: Date?

    private var requestId: String =
        UUID().uuidString

    private var responseData =
        Data()

    override class func canInit(
        with request: URLRequest
    ) -> Bool {

        guard
            URLProtocol.property(
                forKey: handledKey,
                in: request
            ) == nil
        else {
            return false
        }

        guard
            let scheme =
                request.url?.scheme?.lowercased()
        else {
            return false
        }

        return scheme == "http"
            || scheme == "https"
    }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {

        request
    }

    override func startLoading() {

        guard
            let observabilityConfiguration =
                APIObservability.shared.configuration,
            observabilityConfiguration.enabled
        else {
            returnOriginalRequest()
            return
        }

        guard
            let host = request.url?.host,
            !observabilityConfiguration.ignoredHosts.contains(host)
        else {
            returnOriginalRequest()
            return
        }

        startDate = Date()
        captureRequest()

        let mutableRequest = NSMutableURLRequest(
            url: request.url!,
            cachePolicy: request.cachePolicy,
            timeoutInterval: request.timeoutInterval
        )

        // Preserve original request properties
        mutableRequest.httpMethod = request.httpMethod ?? "GET"
        mutableRequest.allHTTPHeaderFields = request.allHTTPHeaderFields
        mutableRequest.httpBody = request.httpBody

        URLProtocol.setProperty(
            true,
            forKey: Self.handledKey,
            in: mutableRequest
        )

        if mutableRequest.value(
            forHTTPHeaderField: "X-Request-ID"
        ) == nil {

            mutableRequest.setValue(
                requestId,
                forHTTPHeaderField: "X-Request-ID"
            )
        }

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = []

        let session = URLSession(
            configuration: sessionConfiguration,
            delegate: self,
            delegateQueue: nil
        )

        self.session = session

        dataTask = session.dataTask(
            with: mutableRequest as URLRequest
        )

        dataTask?.resume()
    }

    override func stopLoading() {

        dataTask?.cancel()

        dataTask = nil

        session?.invalidateAndCancel()

        session = nil
    }

    private func returnOriginalRequest() {

        let mutableRequest = NSMutableURLRequest(
            url: request.url!,
            cachePolicy: request.cachePolicy,
            timeoutInterval: request.timeoutInterval
        )

        URLProtocol.setProperty(
            true,
            forKey: Self.handledKey,
            in: mutableRequest
        )

        
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = []

        let session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )

        self.session = session

        dataTask = session.dataTask(with: mutableRequest as URLRequest)
        dataTask?.resume()
    }

    private func captureRequest() {

        guard
            let configuration =
                APIObservability.shared.configuration
        else {
            return
        }

        let headers =
            configuration.logRequestHeaders
            ? APILogSanitizer.sanitizeHeaders(
                request.allHTTPHeaderFields,
                sensitiveKeys:
                    configuration.sensitiveHeaders
            )
            : nil

        let body =
            configuration.logRequestBody
            ? APILogSanitizer.sanitizeBody(
                request.httpBody,
                sensitiveKeys:
                    configuration.sensitiveBodyKeys,
                maxSize:
                    configuration.maxBodySize
            )
            : nil

        print("""
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        API REQUEST
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        Request ID:
        \(requestId)

        Method:
        \(request.httpMethod ?? "UNKNOWN")

        URL:
        \(request.url?.absoluteString ?? "")

        Headers:
        \(headers ?? [:])

        Body:
        \(body ?? "nil")

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """)
    }

    private func captureResponse(
        error: Error?
    ) {

        let completedAt =
            Date()

        let startedAt =
            startDate ?? completedAt

        let duration =
            completedAt.timeIntervalSince(
                startedAt
            )

        let response =
            dataTask?.response as? HTTPURLResponse

        let configuration =
            APIObservability.shared.configuration

        let responseHeaders =
            configuration?.logResponseHeaders == true
            ? response?.allHeaderFields.reduce(
                into: [String: String]()
            ) {
                $0[
                    String(describing: $1.key)
                ] =
                    String(describing: $1.value)
            }
            : nil

        let responseBody =
            configuration?.logResponseBody == true
            ? APILogSanitizer.sanitizeBody(
                responseData,
                sensitiveKeys:
                    configuration?.sensitiveBodyKeys
                    ?? [],
                maxSize:
                    configuration?.maxBodySize
                    ?? 1_000_000
            )
            : nil

        let durationMs =
            Int(duration * 1000)

        let log =
            APIRequestLog(
                requestId: requestId,
                url:
                    request.url?
                    .absoluteString
                    ?? "",
                method:
                    request.httpMethod
                    ?? "UNKNOWN",
                requestHeaders:
                    configuration?.logRequestHeaders == true
                    ? APILogSanitizer.sanitizeHeaders(
                        request.allHTTPHeaderFields,
                        sensitiveKeys:
                            configuration?
                            .sensitiveHeaders
                            ?? []
                    )
                    : nil,
                requestBody:
                    configuration?.logRequestBody == true
                    ? APILogSanitizer.sanitizeBody(
                        request.httpBody,
                        sensitiveKeys:
                            configuration?
                            .sensitiveBodyKeys
                            ?? [],
                        maxSize:
                            configuration?
                            .maxBodySize
                            ?? 1_000_000
                    )
                    : nil,
                responseStatus:
                    response?.statusCode,
                responseHeaders:
                    responseHeaders,
                responseBody:
                    responseBody,
                error:
                    error?.localizedDescription,
                startedAt:
                    startedAt,
                completedAt:
                    completedAt,
                durationMs:
                    durationMs,
                appVersion:
                    APIObservabilityDeviceInfo
                    .appVersion,
                iosVersion:
                    APIObservabilityDeviceInfo
                    .iosVersion,
                deviceModel:
                    APIObservabilityDeviceInfo
                    .deviceModel,
                networkType:
                    APINetworkInfo.shared.networkType,
                timezone:
                    APIObservabilityDeviceInfo
                    .timezone,
                country:
                    APIObservabilityDeviceInfo
                    .country,
                bundleId: APIObservabilityDeviceInfo.bundleId,
                appUserId: configuration?.appUserId,
                appUserEmail: configuration?.appUserEmail,
                logintype: configuration?.logintype,
                deviceId: configuration?.deviceId
                
            )

        APIObservabilityStore.shared
            .save(log)

        print("""
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        API RESPONSE
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        Request ID:
        \(requestId)

        Status:
        \(response?.statusCode ?? 0)

        Duration:
        \(durationMs) ms

        Response:
        \(responseBody ?? "nil")

        Error:
        \(error?.localizedDescription ?? "nil")

        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """)
    }
}

extension APIObservabilityURLProtocol:
    URLSessionDataDelegate {

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler:
            @escaping (
                URLSession.ResponseDisposition
            ) -> Void
    ) {

        client?.urlProtocol(
            self,
            didReceive:
                response,
            cacheStoragePolicy:
                .notAllowed
        )

        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {

        responseData.append(data)

        client?.urlProtocol(
            self,
            didLoad: data
        )
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {

        captureResponse(
            error: error
        )

        if let error {

            client?.urlProtocol(
                self,
                didFailWithError:
                    error
            )

        } else {

            client?.urlProtocolDidFinishLoading(
                self
            )
        }

        self.dataTask = nil

        self.session = nil
    }
}
