//
//  AIProxyURLRequest.swift
//
//
//  Created by Lou Zell on 8/6/24.
//

import Foundation

@AIProxyActor enum AIProxyURLRequest {

    /// Creates a URLRequest that targets the service provider directly (BYOK).
    /// The hosted-proxy variant has been removed in this fork.
    static func createDirect(
        baseURL: String,
        path: String,
        body: Data?,
        verb: AIProxyHTTPVerb,
        secondsToWait: UInt,
        contentType: String? = nil,
        additionalHeaders: [String: String] = [:]
    ) throws -> URLRequest {
        var path = path
        if !path.starts(with: "/") {
            path = "/\(path)"
        }

        guard var urlComponents = URLComponents(string: baseURL),
              let pathComponents = URLComponents(string: path) else {
            throw AIProxyError.assertion(
                "Could not create urlComponents for the direct-to-provider use case"
            )
        }

        urlComponents.path += pathComponents.path
        urlComponents.queryItems = pathComponents.queryItems

        guard let url = urlComponents.url else {
            throw AIProxyError.assertion("Could not create a request URL")
        }

        var request = URLRequest(url: url)
        request.networkServiceType = .avStreaming
        request.httpMethod = verb.toString(hasBody: body != nil)
        request.httpBody = body

        if let contentType = contentType {
            request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        for (headerField, value) in additionalHeaders {
            request.addValue(value, forHTTPHeaderField: headerField)
        }

        request.timeoutInterval = TimeInterval(secondsToWait)
        return request
    }
}
