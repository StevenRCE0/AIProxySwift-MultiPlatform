//
//  Networker.swift
//
//
//  Created by Lou Zell on 8/24/24.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(FoundationNetworking)
/// Linux stand-in for `URLSession.AsyncBytes`. swift-corelibs-foundation has no
/// async `URLSession.bytes`, so streaming responses are delivered through the
/// delegate-based chunk stream (see `makeRequestAndVendChunksWithResponse`) and
/// split into lines here. Exposes `.lines` (yielding `String`) so the streaming
/// call sites are identical to the Apple `URLSession.AsyncBytes.lines` path.
struct AIProxyAsyncLines: AsyncSequence, Sendable {
    typealias Element = String
    let stream: AsyncThrowingStream<String, Error>
    func makeAsyncIterator() -> AsyncThrowingStream<String, Error>.Iterator {
        stream.makeAsyncIterator()
    }
    var lines: AIProxyAsyncLines { self }
}
typealias AIProxyResponseBytes = AIProxyAsyncLines
#else
typealias AIProxyResponseBytes = URLSession.AsyncBytes
#endif

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
    @AIProxyActor static func makeRequestAndWaitForAsyncBytes(
        _ session: URLSession,
        _ request: URLRequest
    ) async throws -> (AIProxyResponseBytes, HTTPURLResponse) {
#if canImport(FoundationNetworking)
        // Linux: no async URLSession.bytes. Reuse the delegate-based chunk stream
        // (which already throws unsuccessfulRequest on a non-2xx status) and split
        // the Data chunks into lines, matching URLSession.AsyncBytes.lines.
        let (dataStream, httpResponse) = try await makeRequestAndVendChunksWithResponse(session, request)
        let lineStream = AsyncThrowingStream<String, Error> { continuation in
            let task = Task {
                var buffer = Data()
                for await chunk in dataStream {
                    buffer.append(chunk)
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
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        return (AIProxyAsyncLines(stream: lineStream), httpResponse)
#else
        let (asyncBytes, res) = try await session.bytes(
            for: request,
            delegate: session.delegate as? URLSessionTaskDelegate
        )

        guard let httpResponse = res as? HTTPURLResponse else {
            throw AIProxyError.assertion("Network response is not an http response")
        }

        if (httpResponse.statusCode > 299) {
            var responseBody = ""
            for try await line in asyncBytes.lines {
                responseBody += line
            }
            throw AIProxyError.unsuccessfulRequest(
                statusCode: httpResponse.statusCode,
                responseBody: responseBody
            )
        }
        return (asyncBytes, httpResponse)
#endif
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
