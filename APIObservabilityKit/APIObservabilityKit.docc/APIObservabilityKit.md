# ``APIObservabilityKit``

Capture API request and response logs, then upload them to a monitoring server.

## Overview

Configure uploads with `APIObservabilityConfiguration`. `interval` controls how
often pending logs are flushed, including partial batches. `batchSize` controls
the maximum number of logs in each request and defaults to 20. A full batch is
uploaded as soon as it is ready; the interval uploads any remaining logs.

For custom `URLSession` instances, configure the session configuration before
creating the session so requests use the observability protocol:

```swift
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 30
config.timeoutIntervalForResource = 30
config.requestCachePolicy = .reloadIgnoringLocalCacheData
let observedConfig =
    APIObservability.shared.configureURLSessionConfiguration(config)
let urlSession = URLSession(configuration: observedConfig)
```

Use this session for your GET and POST tasks. Start the framework before creating
the session. Set `includedHosts: ["api.menaflix.com"]` in the startup configuration
to capture only that API host and exclude unrelated analytics traffic. An empty
set captures all eligible hosts. `ignoredHosts` takes precedence. Request and
response log entries include the same request ID and original URL.

The `logRequestHeaders`, `logRequestBody`, `logResponseHeaders`, and
`logResponseBody` flags control console fields only. The independent
`uploadRequestHeaders`, `uploadRequestBody`, `uploadResponseHeaders`, and
`uploadResponseBody` flags control uploaded fields and all default to `true`.
For example, `logResponseBody: false` with `uploadResponseBody: true` hides the
response body in the console while including it in monitoring uploads.
Captured responses are eligible for upload for every HTTP status code, including
failed responses. Body limits, redaction, and host filters still apply.

Set `uploadLogs: false` to disable monitoring uploads. Response bodies are logged
before application-level decoding or decryption. Background URL sessions and
custom outer-session authentication delegates are not supported by this helper.


Command to build:
```sh
cd /Users/ishpreetsingh/Desktop/Projects/APIObservabilityKit
bash scripts/build-xcframework.sh build/APIObservabilityKit-release.xcframework
```


## Topics

### Configuration

- ``APIObservabilityConfiguration``
- ``APIObservability/start(configuration:)``
