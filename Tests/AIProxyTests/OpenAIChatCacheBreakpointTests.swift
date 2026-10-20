//
//  OpenAIChatCacheBreakpointTests.swift
//

import XCTest
@testable import AIProxy

final class OpenAIChatCacheBreakpointTests: XCTestCase {

    func testSystemTextBecomesOnePartWithCacheControl() throws {
        let message = OpenAIChatCompletionRequestBody.Message.cacheBreakpoint(
            .system(content: .text("stable")),
            cacheControl: .init(ttl: "1h")
        )
        XCTAssertEqual(
            """
            {
              "content" : [
                {
                  "cache_control" : {
                    "ttl" : "1h",
                    "type" : "ephemeral"
                  },
                  "text" : "stable",
                  "type" : "text"
                }
              ],
              "role" : "system"
            }
            """,
            try message.serialize(pretty: true)
        )
    }

    func testOnlyTheLastPartCarriesTheControl() throws {
        let message = OpenAIChatCompletionRequestBody.Message.cacheBreakpoint(
            .user(content: .parts([.text("first"), .text("last")]), name: "ada"),
            cacheControl: .ephemeral
        )
        let data: Data = try message.serialize()
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let parts = try XCTUnwrap(object["content"] as? [[String: Any]])
        XCTAssertEqual(parts.map { $0["text"] as? String }, ["first", "last"])
        XCTAssertNil(parts[0]["cache_control"])
        XCTAssertEqual(parts[1]["cache_control"] as? [String: String], ["type": "ephemeral"])
        XCTAssertEqual(object["name"] as? String, "ada")
        XCTAssertEqual(object["role"] as? String, "user")
    }

    func testAssistantWithoutContentKeepsItsToolCalls() throws {
        let message = OpenAIChatCompletionRequestBody.Message.cacheBreakpoint(
            .assistant(
                content: nil,
                toolCalls: [.init(id: "call_1", function: .init(name: "lookup", arguments: "{}"))]
            ),
            cacheControl: .ephemeral
        )
        let json: String = try message.serialize()
        XCTAssertFalse(json.contains("cache_control"), "no content, nothing to mark")
        XCTAssertTrue(json.contains(#""tool_calls""#))
        XCTAssertTrue(json.contains(#""role":"assistant""#))
    }

    func testPlainMessagesAreUnchanged() throws {
        let message = OpenAIChatCompletionRequestBody.Message.system(content: .text("stable"))
        let json: String = try message.serialize()
        XCTAssertEqual(#"{"content":"stable","role":"system"}"#, json)
    }
}
