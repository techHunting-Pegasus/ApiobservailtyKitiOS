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

    private var captureConfiguration: APIObservabilityConfiguration?

    private var requestId: String =
        UUID().uuidString

    private var responseData =
        Data()

    private var responseBodyTruncated = false

    private var requestBodyData: Data?
    private var requestBodyTruncated = false
    private var forwardedBodyFileURL: URL?

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

        return (scheme == "http" || scheme == "https")
            && APIObservability.shared.shouldCapture(request)
    }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {

        request
    }

    override func startLoading() {

        if APIObservability.shared.shouldCapture(request) {
            captureConfiguration = APIObservability.shared.configuration
            requestId = request.value(forHTTPHeaderField: "X-Request-ID")
                ?? UUID().uuidString
            startDate = Date()
        }

        // A full copy preserves POST bodies, body streams, headers and request
        // policies, including when capture has been disabled since canInit.
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest

        do {
            try prepareRequestBody(mutableRequest)
        } catch {
            removeForwardedBodyFile()
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if captureConfiguration != nil {
            captureRequest()
        }

        URLProtocol.setProperty(
            true,
            forKey: Self.handledKey,
            in: mutableRequest
        )

        if captureConfiguration != nil && mutableRequest.value(
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
        removeForwardedBodyFile()
    }

    private func prepareRequestBody(_ forwardedRequest: NSMutableURLRequest) throws {
        guard let configuration = captureConfiguration,
              configuration.logRequestBody
                || (configuration.uploadLogs && configuration.uploadRequestBody) else {
            return
        }
        if let body = request.httpBody {
            requestBodyTruncated = body.count > configuration.maxBodySize
            requestBodyData = Data(body.prefix(configuration.maxBodySize))
            return
        }
        guard let stream = request.httpBodyStream else { return }

        // URLSession often exposes even a data-backed POST as a body stream.
        // Spool it to a private file so logging does not consume the payload or
        // retain an unbounded upload in memory. Forward a fresh stream afterward.
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("api-observability-body-\(UUID().uuidString)")
        forwardedBodyFileURL = fileURL
        guard FileManager.default.createFile(
            atPath: fileURL.path, contents: nil, attributes: [.posixPermissions: 0o600]
        ), let output = OutputStream(url: fileURL, append: false) else {
            throw CocoaError(.fileWriteUnknown)
        }
        stream.open()
        output.open()
        defer {
            stream.close()
            output.close()
        }
        requestBodyData = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { throw stream.streamError ?? CocoaError(.fileReadUnknown) }
            if count == 0 { break }
            let remaining = max(0, configuration.maxBodySize - (requestBodyData?.count ?? 0))
            requestBodyTruncated = requestBodyTruncated || count > remaining
            requestBodyData?.append(contentsOf: buffer.prefix(min(count, remaining)))
            try buffer.withUnsafeBufferPointer { bytes in
                var written = 0
                while written < count {
                    let size = output.write(bytes.baseAddress! + written, maxLength: count - written)
                    guard size > 0 else { throw output.streamError ?? CocoaError(.fileWriteUnknown) }
                    written += size
                }
            }
        }
        forwardedRequest.httpBodyStream = InputStream(url: fileURL)
    }

    private func removeForwardedBodyFile() {
        if let fileURL = forwardedBodyFileURL {
            try? FileManager.default.removeItem(at: fileURL)
            forwardedBodyFileURL = nil
        }
    }

    private func capturedRequestBody(configuration: APIObservabilityConfiguration) -> String? {
        if requestBodyTruncated { return "[Body omitted: exceeds maxBodySize]" }
        return APILogSanitizer.sanitizeBody(
            requestBodyData,
            sensitiveKeys: configuration.sensitiveBodyKeys,
            maxSize: configuration.maxBodySize
        )
    }

    private func captureRequest() {

        guard
            let configuration =
                captureConfiguration
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

        let body = configuration.logRequestBody
            ? capturedRequestBody(configuration: configuration) : nil

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

        guard let configuration = captureConfiguration,
              APIObservability.shared.configuration?.enabled == true else {
            return
        }

        let rawResponseHeaders = response?.allHeaderFields.reduce(into: [String: String]()) {
            $0[String(describing: $1.key)] = String(describing: $1.value)
        }
        let responseHeaders = (configuration.logResponseHeaders
            || (configuration.uploadLogs && configuration.uploadResponseHeaders))
            ? APILogSanitizer.sanitizeHeaders(
                rawResponseHeaders,
                sensitiveKeys: configuration.sensitiveHeaders
            )
            : nil

        let responseBody =
            (configuration.logResponseBody
                || (configuration.uploadLogs && configuration.uploadResponseBody))
            ? (responseBodyTruncated ? "[Body omitted: exceeds maxBodySize]" : APILogSanitizer.sanitizeBody(
                responseData,
                sensitiveKeys:
                    configuration.sensitiveBodyKeys,
                maxSize:
                    configuration.maxBodySize
            ))
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
                    configuration.uploadRequestHeaders
                    ? APILogSanitizer.sanitizeHeaders(
                        request.allHTTPHeaderFields,
                        sensitiveKeys:
                            configuration
                            .sensitiveHeaders
                    )
                    : nil,
                requestBody: configuration.uploadRequestBody
                    ? capturedRequestBody(configuration: configuration) : nil,
                responseStatus:
                    response?.statusCode,
                responseHeaders:
                    configuration.uploadResponseHeaders ? responseHeaders : nil,
                responseBody:
                    configuration.uploadResponseBody ? responseBody : nil,
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
                appUserId: configuration.appUserId,
                appUserEmail: configuration.appUserEmail,
                logintype: configuration.logintype,
                deviceId: configuration.deviceId
                
            )

        APIObservabilityStore.shared
            .save(log)

        print("""
        
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        API RESPONSE
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        Request ID:
        \(requestId)

        Method:
        \(request.httpMethod ?? "UNKNOWN")

        URL:
        \(request.url?.absoluteString ?? "")

        Status:
        \(response?.statusCode ?? 0)

        Headers:
        \(configuration.logResponseHeaders ? (responseHeaders ?? [:]) : [:])

        Duration:
        \(durationMs) ms

        Response:
        \(configuration.logResponseBody ? (responseBody ?? "nil") : "nil")

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

        if let configuration = captureConfiguration,
           configuration.logResponseBody
            || (configuration.uploadLogs && configuration.uploadResponseBody) {
            let remaining = max(0, configuration.maxBodySize - responseData.count)
            responseBodyTruncated = responseBodyTruncated || data.count > remaining
            responseData.append(data.prefix(remaining))
        }

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

        session.finishTasksAndInvalidate()
        self.dataTask = nil
        self.session = nil
        removeForwardedBodyFile()
    }
}
