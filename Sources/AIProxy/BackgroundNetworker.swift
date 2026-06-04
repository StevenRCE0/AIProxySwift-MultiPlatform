//
//  Networker.swift
//
//
//  Created by Lou Zell on 8/24/24.

import Foundation
import AsyncHTTPClient
import NIOCore
import NIOHTTP1
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A stream of response lines (yields `String`). Streaming responses go through
/// the NIO HTTP stack (AsyncHTTPClient) on every platform — Linux's
/// FoundationNetworking has no async `URLSession.bytes` — so there's a single,
/// non-diverging code path. `.lines` mirrors `URLSession.AsyncBytes.lines`, so
/// streaming call sites are platform-agnostic.
struct AIProxyAsyncLines: AsyncSequence, Sendable {
    typealias Element = String
    let stream: AsyncThrowingStream<String, Error>
    func makeAsyncIterator() -> AsyncThrowingStream<String, Error>.Iterator {
        stream.makeAsyncIterator()
    }
    var lines: AIProxyAsyncLines { self }
}
typealias AIProxyResponseBytes = AIProxyAsyncLines

struct BackgroundNetworker {

    /// Throws AIProxyError.unsuccessfulRequest if the returned status code is non-200
    ///
    /// `progressCallback` is accepted for API compatibility but is currently a no-op
    /// in this fork: the upstream implementation routed it through the proxy's
    /// certificate-pinning delegate, which has been removed.
    @AIProxyActor static func makeRequestAndWaitForData(
        _ session: URLSession,
        _ request: URLRequest,
        _ progressCallback: (@Sendable (Double) -> Void)? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        _ = progressCallback
        let (data, res) = try await session.data(
            for: request,
            delegate: session.delegate as? URLSessionTaskDelegate
        )
        guard let httpResponse = res as? HTTPURLResponse else {
            throw AIProxyError.assertion("Network response is not an http response")
        }
        if httpResponse.statusCode > 299 {
            logIf(.error)?.error("Receieved a non-200 status code: \(httpResponse.statusCode)")
            throw AIProxyError.unsuccessfulRequest(
                statusCode: httpResponse.statusCode,
                responseBody: String(data: data, encoding: .utf8) ?? ""
            )
        }
        return (data, httpResponse)
    }

    /// Throws AIProxyError.unsuccessfulRequest if the returned status code is non-200
    ///
    /// Streaming runs on the NIO HTTP stack (`HTTPClient.shared`, no lifecycle to
    /// manage) on every platform, so there's no per-platform divergence. The
    /// `session` is unused here — the request carries all headers/auth/body — and
    /// is kept only for call-site compatibility with the non-streaming helpers.
    @AIProxyActor static func makeRequestAndWaitForAsyncBytes(
        _ session: URLSession,
        _ request: URLRequest
    ) async throws -> (AIProxyResponseBytes, HTTPURLResponse) {
        _ = session
        guard let url = request.url else {
            throw AIProxyError.assertion("Request has no URL")
        }

        var hreq = HTTPClientRequest(url: url.absoluteString)
        switch (request.httpMethod ?? "GET").uppercased() {
        case "GET": hreq.method = .GET
        case "POST": hreq.method = .POST
        case "PUT": hreq.method = .PUT
        case "DELETE": hreq.method = .DELETE
        case "PATCH": hreq.method = .PATCH
        case let other: hreq.method = .RAW(value: other)
        }
        for (name, value) in request.allHTTPHeaderFields ?? [:] {
            hreq.headers.add(name: name, value: value)
        }
        if let body = request.httpBody {
            hreq.body = .bytes(ByteBuffer(bytes: body))
        }
        let seconds = request.timeoutInterval > 0 ? Int64(request.timeoutInterval) : 60
        let response = try await HTTPClient.shared.execute(hreq, timeout: .seconds(seconds))

        // Rebuild an HTTPURLResponse so callers can read response metadata as before.
        var headerFields: [String: String] = [:]
        for field in response.headers { headerFields[field.name] = field.value }
        // Note: HTTPURLResponse() (no-arg) exists on Apple but not on Linux
        // (swift-corelibs-foundation), so handle the failable init explicitly.
        guard let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: Int(response.status.code),
            httpVersion: "HTTP/1.1",
            headerFields: headerFields
        ) else {
            throw AIProxyError.assertion("Could not construct HTTPURLResponse")
        }

        if response.status.code > 299 {
            var responseBody = ""
            for try await chunk in response.body {
                responseBody += String(decoding: chunk.readableBytesView, as: UTF8.self)
            }
            throw AIProxyError.unsuccessfulRequest(
                statusCode: Int(response.status.code),
                responseBody: responseBody
            )
        }

        let lineStream = AsyncThrowingStream<String, Error> { continuation in
            let task = Task {
                do {
                    var buffer = Data()
                    for try await chunk in response.body {
                        buffer.append(contentsOf: chunk.readableBytesView)
                        while let nl = buffer.firstIndex(of: 0x0A) {
                            var lineData = Data(buffer[buffer.startIndex..<nl])
                            if lineData.last == 0x0D { lineData.removeLast() }  // strip CR (CRLF)
                            continuation.yield(String(decoding: lineData, as: UTF8.self))
                            buffer.removeSubrange(buffer.startIndex...nl)
                        }
                    }
                    if !buffer.isEmpty {
                        continuation.yield(String(decoding: buffer, as: UTF8.self))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        return (AIProxyAsyncLines(stream: lineStream), httpResponse)
    }

    @AIProxyActor static func makeRequestAndVendChunks(
        _ session: URLSession,
        _ request: URLRequest
    ) async throws -> AsyncStream<Data> {
        let (stream, _) = try await self.makeRequestAndVendChunksWithResponse(session, request)
        return stream
    }

    @AIProxyActor static func makeRequestAndVendChunksWithResponse(
        _ session: URLSession,
        _ request: URLRequest
    ) async throws -> (AsyncStream<Data>, HTTPURLResponse) {

        let dataTaskBridge = URLSessionDataTaskBridge()
        let task = session.dataTask(with: request)

        if let directDelegate = session.delegate as? DirectURLSessionDataDelegate {
            directDelegate.addBridge(for: task, box: dataTaskBridge)
        }

        let asyncStream = AsyncStream { [weak dataTaskBridge] continuation in
            guard let dataTaskBridge = dataTaskBridge else { return }
            dataTaskBridge.onData.append({ data in
                Task { @AIProxyActor in
                    continuation.yield(data)
                }
            })

            dataTaskBridge.onComplete.append({ err in
                Task { @AIProxyActor in
                    if let err = err {
                        logIf(.error)?.error("AIProxy: received error from Foundation: \(err.localizedDescription)")
                    }
                    continuation.finish()
                }
            })
        }

        let httpResponse: HTTPURLResponse = try await withCheckedThrowingContinuation { @AIProxyActor continuation in
            task.resume()
            dataTaskBridge.onResponse.append { [weak dataTaskBridge] res in
                guard let dataTaskBridge = dataTaskBridge else { return }
                guard let httpResponse = res as? HTTPURLResponse else {
                    continuation.resume(throwing: AIProxyError.assertion("Network response is not an http response"))
                    return
                }
                dataTaskBridge.statusCode = httpResponse.statusCode
                if !dataTaskBridge.isBadStatusCode {
                    dataTaskBridge.responseDelivered = true
                    continuation.resume(returning: httpResponse)
                }
            }

            dataTaskBridge.onData.append { [weak dataTaskBridge] data in
                guard let dataTaskBridge = dataTaskBridge else { return }
                if dataTaskBridge.isBadStatusCode {
                    dataTaskBridge.accumulatedErrorBody += data
                }
            }

            dataTaskBridge.onComplete.append { [weak dataTaskBridge] err in
                guard let dataTaskBridge = dataTaskBridge else { return }
                if dataTaskBridge.responseDelivered {
                    return
                }
                if let err = err {
                    dataTaskBridge.responseDelivered = true
                    continuation.resume(throwing: err)
                    return
                }
                if dataTaskBridge.isBadStatusCode {
                    let err = AIProxyError.unsuccessfulRequest(
                        statusCode: dataTaskBridge.statusCode,
                        responseBody: String(data: dataTaskBridge.accumulatedErrorBody, encoding: .utf8) ?? ""
                    )
                    dataTaskBridge.responseDelivered = true
                    continuation.resume(throwing: err)
                }
            }
        }

        return (asyncStream, httpResponse)
    }
}
