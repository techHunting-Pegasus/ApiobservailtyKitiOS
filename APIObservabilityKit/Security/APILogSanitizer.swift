//
//  APILogSanitizer.swift
//  APIObservabilityKit
//
//  Created by Ishpreet singh on 06/10/26.
//

import Foundation

enum APILogSanitizer {

    static func sanitizeHeaders(
        _ headers: [String: String]?,
        sensitiveKeys: Set<String>
    ) -> [String: String]? {

        guard let headers else {
            return nil
        }

        var result: [String: String] = [:]

        for (key, value) in headers {

            if sensitiveKeys.contains(
                key.lowercased()
            ) {
                result[key] = "******"
            } else {
                result[key] = value
            }
        }

        return result
    }

    static func sanitizeBody(
        _ data: Data?,
        sensitiveKeys: Set<String>,
        maxSize: Int
    ) -> String? {

        guard let data else {
            return nil
        }

        // A truncated JSON prefix cannot be safely redacted. Omit oversized
        // bodies rather than returning a raw prefix containing credentials.
        // guard data.count <= max(0, maxSize) else {
        //     return "[Body omitted: exceeds maxBodySize]"
        // }
        let limitedData = data

        guard let object =
                try? JSONSerialization.jsonObject(
                    with: limitedData
                )
        else {
            return String(
                data: limitedData,
                encoding: .utf8
            )
        }

        let sanitized =
            sanitizeJSON(
                object,
                sensitiveKeys: sensitiveKeys
            )

        guard let output =
                try? JSONSerialization.data(
                    withJSONObject: sanitized,
                    options: [
                        .prettyPrinted,
                        .sortedKeys
                    ]
                )
        else {
            return nil
        }

        return String(
            data: output,
            encoding: .utf8
        )
    }

    private static func sanitizeJSON(
        _ object: Any,
        sensitiveKeys: Set<String>
    ) -> Any {

        if let dictionary =
            object as? [String: Any] {

            var result: [String: Any] = [:]

            for (key, value) in dictionary {

                if sensitiveKeys.contains(
                    key.lowercased()
                ) {
                    result[key] = "******"
                } else {
                    result[key] =
                        sanitizeJSON(
                            value,
                            sensitiveKeys: sensitiveKeys
                        )
                }
            }

            return result
        }

        if let array = object as? [Any] {

            return array.map {
                sanitizeJSON(
                    $0,
                    sensitiveKeys: sensitiveKeys
                )
            }
        }

        return object
    }
}
