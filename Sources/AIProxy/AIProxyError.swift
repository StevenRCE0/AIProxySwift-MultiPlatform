//
//  AIProxyError.swift
//
//
//  Created by Lou Zell on 6/23/24.
//

import Foundation

nonisolated public enum AIProxyError: LocalizedError, Equatable, Sendable {

    /// Thrown for broken library invariants — programmer errors that the library can't recover from.
    /// Any AIProxyError.assertion you encounter in the wild is a bug; please file an issue.
    case assertion(String)

    /// Raised when the status code of a network response is outside of the [200, 299] range.
    /// The associated Int is the status code; the associated String is the response body.
    case unsuccessfulRequest(statusCode: Int, responseBody: String)

    public var errorDescription: String? {
        switch self {
        case .assertion(let message):
            return "AIProxy - A library precondition was not met: \(message)"
        case .unsuccessfulRequest(statusCode: let statusCode, responseBody: let responseBody):
            return "AIProxy - the request resulted in a status code of \(statusCode) with response body: \(responseBody)."
        }
    }
}
