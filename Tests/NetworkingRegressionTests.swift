import Foundation

private final class ResultBox: @unchecked Sendable {
    let finished = DispatchSemaphore(value: 0)
    var data: Data?
    var error: Error?
}

private final class OtherProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { false }
}

@main
enum NetworkingRegressionTests {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }

    static func send(_ request: URLRequest, using session: URLSession) throws -> [String: Any] {
        let result = ResultBox()
        session.dataTask(with: request) { data, _, error in
            result.data = data
            result.error = error
            result.finished.signal()
        }.resume()
        check(result.finished.wait(timeout: .now() + 10) == .success, "Request timed out")
        if let error = result.error { throw error }
        return try JSONSerialization.jsonObject(with: result.data!) as! [String: Any]
    }

    static func main() throws {
        let root = CommandLine.arguments[1]
        let sdk = APIObservability.shared
        sdk.start(configuration: .init(
            uploadLogs: false,
            interval: 3600,
            batchSize: 1000,
            monitoringURL: URL(string: root + "/monitor"),
            sensitiveHeaders: ["Authorization", "Set-Cookie"],
            sensitiveBodyKeys: ["Password"],
            includedHosts: ["127.0.0.1"]
        ))
        defer { sdk.stop() }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = ["country": "IN"]
        config.protocolClasses = [OtherProtocol.self]
        let observed = sdk.configureURLSessionConfiguration(config)
        let twice = sdk.configureURLSessionConfiguration(observed)
        check(observed !== config, "The caller's configuration must be copied")
        check(config.protocolClasses?.count == 1, "The original configuration was mutated")
        check(twice.protocolClasses?.filter { $0 == APIObservabilityURLProtocol.self }.count == 1,
              "Interceptor was installed more than once")
        check(twice.protocolClasses?.contains { $0 == OtherProtocol.self } == true,
              "Another protocol was removed")
        check(twice.timeoutIntervalForRequest == 30 && twice.timeoutIntervalForResource == 30,
              "Timeouts changed")

        check(APIObservabilityURLProtocol.canInit(with: URLRequest(url: URL(string: root + "/get")!)),
              "App API is not captured")
        check(!APIObservabilityURLProtocol.canInit(with: URLRequest(
            url: URL(string: "https://a-fds.youborafds01.com/data")!)), "Analytics should be excluded")
        check(!APIObservabilityURLProtocol.canInit(with: URLRequest(url: URL(string: root + "/monitor")!)),
              "Monitoring endpoint should be excluded")

        let session = URLSession(configuration: twice)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: URL(string: root + "/get?asset=274367")!)
        request.setValue("test-token", forHTTPHeaderField: "Authorization")
        request.setValue("existing-request-id", forHTTPHeaderField: "X-Request-ID")
        let get = try send(request, using: session)
        check(get["method"] as? String == "GET", "GET method changed")
        check(get["path"] as? String == "/get?asset=274367", "Request URL changed")
        let headers = get["headers"] as! [String: String]
        check(headers["authorization"] == "test-token", "Authorization did not reach the server")
        check(headers["country"] == "IN", "Session headers did not reach the server")
        check(headers["x-request-id"] == "existing-request-id", "Request ID changed")

        request.url = URL(string: root + "/post")!
        request.setValue("post-request-id", forHTTPHeaderField: "X-Request-ID")
        request.httpMethod = "POST"
        request.httpBody = Data(#"{"password":"test-secret","asset":274367}"#.utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let post = try send(request, using: session)
        check(post["method"] as? String == "POST", "POST method changed")
        check(post["body"] as? String == String(data: request.httpBody!, encoding: .utf8),
              "POST body changed")

        let logs = APIObservabilityStore.shared.pendingLogs(limit: 100)
        check(logs.count == 2, "Expected one log per observed request")
        check(logs[0].url == root + "/get?asset=274367", "Captured the wrong URL")
        check(logs[0].requestId == "existing-request-id", "Request and log IDs do not match")
        check(logs[0].requestHeaders?["Authorization"] == "******", "Request token was not redacted")
        check(logs[0].responseHeaders?.first { $0.key.lowercased() == "set-cookie" }?.value == "******",
              "Response cookie was not redacted")
        check(logs[1].requestBody?.contains("test-secret") == false, "Request password was not redacted")
        let responseJSON = try JSONSerialization.jsonObject(
            with: Data(logs[1].responseBody!.utf8)) as! [String: Any]
        check(responseJSON["password"] as? String == "******", "Response password was not redacted")

        var streamed = request
        streamed.httpBody = nil
        streamed.httpBodyStream = InputStream(data: request.httpBody!)
        streamed.setValue("stream-request-id", forHTTPHeaderField: "X-Request-ID")
        streamed.setValue(String(request.httpBody!.count), forHTTPHeaderField: "Content-Length")
        let streamResult = try send(streamed, using: session)
        check(streamResult["body"] as? String == String(data: request.httpBody!, encoding: .utf8),
              "Streamed POST lost its body")
        let streamLog = APIObservabilityStore.shared.pendingLogs(limit: 100).last!
        check(streamLog.requestBody?.contains("******") == true, "Streamed POST was not captured")

        // Restart with an existing configured session to verify filters still apply.
        sdk.stop()
        sdk.start(configuration: .init(
            uploadLogs: false,
            ignoredHosts: ["127.0.0.1"],
            includedHosts: ["127.0.0.1"]
        ))
        check(!APIObservabilityURLProtocol.canInit(with: request), "Ignored host was intercepted")
        let ignored = try send(request, using: session)
        check(ignored["method"] as? String == "POST", "Ignored POST changed into GET")
        check(ignored["body"] as? String == String(data: request.httpBody!, encoding: .utf8),
              "Ignored POST lost its body")
        check(APIObservabilityStore.shared.pendingLogs(limit: 100).count == 3, "Ignored request was logged")

        sdk.stop()
        sdk.start(configuration: .init(enabled: false, uploadLogs: false))
        check(!APIObservabilityURLProtocol.canInit(with: request), "Disabled SDK intercepted a request")
        let disabled = try send(request, using: session)
        check(disabled["method"] as? String == "POST", "Disabled SDK changed the method")
        check(APIObservabilityStore.shared.pendingLogs(limit: 100).count == 3, "Disabled SDK logged a request")

        let truncated = APILogSanitizer.sanitizeBody(
            Data(#"{"password":"secret","padding":"abcdefghijklmnopqrstuvwxyz"}"#.utf8),
            sensitiveKeys: ["password"], maxSize: 30)
        check(truncated?.contains("secret") == false, "Oversized body leaked a secret")

        // Inspect actual monitoring POSTs as well as in-memory logs. Cover all
        // 16 upload flag combinations, with the console flags set oppositely.
        sdk.stop()
        APIObservabilityStore.shared.removeAll()
        check(APIObservabilityStore.shared.pendingLogs(limit: 100).isEmpty, "Store did not clear")
        for mask in 0..<16 {
            sdk.start(configuration: .init(
                logRequestHeaders: mask & 1 == 0,
                logRequestBody: mask & 2 == 0,
                logResponseHeaders: mask & 4 == 0,
                logResponseBody: mask & 8 == 0,
                uploadLogs: true,
                interval: 3600,
                batchSize: 1,
                monitoringURL: URL(string: root + "/monitor"),
                sensitiveHeaders: ["Authorization", "Set-Cookie"],
                includedHosts: ["127.0.0.1"],
                uploadRequestHeaders: mask & 1 != 0,
                uploadRequestBody: mask & 2 != 0,
                uploadResponseHeaders: mask & 4 != 0,
                uploadResponseBody: mask & 8 != 0
            ))
            var uploadRequest = request
            uploadRequest.setValue("upload-mask-\(mask)", forHTTPHeaderField: "X-Request-ID")
            _ = try send(uploadRequest, using: session)
            waitForUpload()
            sdk.stop()
        }

        // Default upload settings must include bodies even when every console
        // field is disabled, including non-2xx application responses.
        sdk.start(configuration: .init(
            logRequestHeaders: false, logRequestBody: false,
            logResponseHeaders: false, logResponseBody: false,
            interval: 3600, batchSize: 1,
            monitoringURL: URL(string: root + "/monitor"),
            includedHosts: ["127.0.0.1"]
        ))
        request.url = URL(string: root + "/http-error")!
        request.setValue("upload-defaults", forHTTPHeaderField: "X-Request-ID")
        _ = try send(request, using: session)
        waitForUpload()
        print("PASS: custom sessions, filters, GET/POST forwarding, correlation, redaction, disabled capture")
    }

    static func waitForUpload() {
        let deadline = Date().addingTimeInterval(10)
        while !APIObservabilityStore.shared.pendingLogs(limit: 100).isEmpty && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.01)
        }
        check(APIObservabilityStore.shared.pendingLogs(limit: 100).isEmpty,
              "Monitoring upload did not complete")
    }
}
