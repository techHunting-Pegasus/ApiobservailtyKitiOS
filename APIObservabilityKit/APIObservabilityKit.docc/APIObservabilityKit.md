# ``APIObservabilityKit``

Capture API request and response logs, then upload them to a monitoring server.

## Overview

Configure uploads with `APIObservabilityConfiguration`. `interval` controls how
often pending logs are flushed, including partial batches. `batchSize` controls
the maximum number of logs in each request and defaults to 20. A full batch is
uploaded as soon as it is ready; the interval uploads any remaining logs.

## Topics

### Configuration

- ``APIObservabilityConfiguration``
- ``APIObservability/start(configuration:)``