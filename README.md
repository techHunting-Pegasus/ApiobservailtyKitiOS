# APIObservabilityKit

## Capture requests from your app

Start the framework once during app startup, before creating your networking
sessions. To capture only your own API and exclude analytics requests such as
Youbora, specify the exact API host names:

```swift
import APIObservabilityKit

APIObservability.shared.start(configuration: .init(
    apikey: "YOUR_MONITORING_API_KEY",
    sensitiveHeaders: ["authorization", "cookie", "set-cookie", "x-api-key"],
    sensitiveBodyKeys: ["password", "token", "access_token", "refresh_token"],
    includedHosts: ["api.menaflix.com"]
))
```

`includedHosts` matches exact host names, ignoring case. Add any other API hosts
you want to observe. An empty set keeps the existing behavior of observing all
HTTP/HTTPS hosts except `ignoredHosts` and the monitoring endpoint. Ignored hosts
take precedence. Filtering controls logging; other requests still run normally.

For a generic networking class such as `HTTP`, create and reuse an explicitly
configured session:

```swift
private static let observedSession: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30
    config.timeoutIntervalForResource = 30
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration:
        APIObservability.shared.configureURLSessionConfiguration(config))
}()
```

Use `observedSession.dataTask(with: request)` in both `doGet` and `doPost`.
Alternatively, in your existing `doGet`, replace only the session creation:

```swift
let observedConfig = APIObservability.shared.configureURLSessionConfiguration(config)
let urlSession = URLSession(configuration: observedConfig)
```

The helper copies the configuration, keeps its settings and other protocol
classes, and installs the interceptor once. Existing sessions must be recreated
to use the new configuration. Keep your original request URL, method, headers,
and body construction. Redaction affects the captured logs; the server receives
the original header and body values.

Match request and response entries by Request ID and URL. Concurrent SDK calls
can appear between your own console messages. A GET request without a payload
normally logs `Body: nil`. Response bodies are captured as received from the
server, before application-level decoding or decryption in `doParse`.

## Console and upload controls

Console output and monitoring payloads have independent field controls:

| Field | Print to console | Include in monitoring upload |
| --- | --- | --- |
| Request headers | `logRequestHeaders` | `uploadRequestHeaders` |
| Request body | `logRequestBody` | `uploadRequestBody` |
| Response headers | `logResponseHeaders` | `uploadResponseHeaders` |
| Response body | `logResponseBody` | `uploadResponseBody` |

All four upload field settings default to `true`, independently of the console
settings. `uploadLogs` is the master switch for monitoring uploads. Disabling an
upload field omits that field from the JSON sent to the monitoring server; URL,
method, status, timing, errors, and configured user/device metadata remain.

For example, hide response bodies in the console but upload all four fields:

```swift
APIObservability.shared.start(configuration: .init(
    logResponseBody: false,
    uploadLogs: true,
    maxBodySize: 100_000_000,
    interval: 10,
    batchSize: 1,
    apikey: "YOUR_MONITORING_API_KEY",
    includedHosts: ["api.menaflix.com"],
    uploadRequestHeaders: true,
    uploadRequestBody: true,
    uploadResponseHeaders: true,
    uploadResponseBody: true
))
```

All captured API completions are eligible for upload, including non-2xx HTTP
responses and network errors. `includedHosts` and `ignoredHosts` still apply.
Body capture remains subject to `maxBodySize`, text decoding, and configured
redaction; oversized bodies are replaced with an omission message. Network
failures may have no response headers or body. Response content is captured
before your app decrypts it. Upload delivery still requires the monitoring server
to accept the payload and API key.

Set `uploadLogs: false` in the startup configuration for console-only debugging.
Session delegates, cookie storage, caches, and other transport settings on the
outer session are not automatically inherited by the interceptor's forwarding
session. Apps with custom authentication delegates or redirect policies need
separate integration testing. Background sessions are not supported by this
URLProtocol integration.

## Run networking regression tests

```sh
bash scripts/test-networking.sh
```

The tests run production networking code on macOS against a local echo server.
Only UIKit device metadata is substituted. They verify custom sessions, host
filtering, GET/POST preservation, request IDs, redaction, disabled capture, and
disabled uploads without contacting production APIs. They also verify actual
monitoring JSON and console output for all 16 upload field combinations, with
opposite console settings, and upload of a failed HTTP response.

## Build the XCFramework

The framework can be built for both physical iOS devices and the iOS Simulator
as one distributable XCFramework. Requires Xcode with the iOS and iOS Simulator
SDKs installed.

From the repository root, run:

```sh
bash scripts/build-xcframework.sh
```

To preserve an existing build, pass a new output path:

```sh
bash scripts/build-xcframework.sh build/APIObservabilityKit-fixed.xcframework
```

The output is `build/APIObservabilityKit.xcframework`. Add that XCFramework to
your app target in Xcode and import the module with:

```swift
import APIObservabilityKit
```

The script creates Release archives for generic iOS and generic iOS Simulator
destinations, then combines them. It does not sign the framework; the consuming
app is signed when it is built.
