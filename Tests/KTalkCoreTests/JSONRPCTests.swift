import Foundation
import Testing
@testable import KTalkCore

@Suite("JSON-RPC 2.0 Tests")
struct JSONRPCTests {

    @Suite("Request Parsing")
    struct RequestParsingTests {

        @Test("Parse valid request (params + int id)")
        func parseValidRequest() throws {
            let json = #"{"jsonrpc":"2.0","method":"chats.list","params":{"limit":10},"id":1}"#
            let request = try JSONRPCProtocol.parseRequest(Data(json.utf8))
            #expect(request.jsonrpc == "2.0")
            #expect(request.method == "chats.list")
            #expect(request.id == .int(1))
            let limit = request.params?["limit"] as? Int
            #expect(limit == 10)
        }

        @Test("Parse request without params")
        func parseRequestWithoutParams() throws {
            let json = #"{"jsonrpc":"2.0","method":"watch.unsubscribe","id":2}"#
            let request = try JSONRPCProtocol.parseRequest(Data(json.utf8))
            #expect(request.method == "watch.unsubscribe")
            #expect(request.params == nil)
            #expect(request.id == .int(2))
        }

        @Test("Parse request with string id")
        func parseRequestWithStringId() throws {
            let json = #"{"jsonrpc":"2.0","method":"chats.list","id":"abc-123"}"#
            let request = try JSONRPCProtocol.parseRequest(Data(json.utf8))
            #expect(request.id == .string("abc-123"))
        }

        @Test("Parse notification request (no id)")
        func parseRequestWithoutId() throws {
            let json = #"{"jsonrpc":"2.0","method":"watch.unsubscribe"}"#
            let request = try JSONRPCProtocol.parseRequest(Data(json.utf8))
            #expect(request.id == nil)
        }

        @Test("Reject invalid jsonrpc version")
        func rejectInvalidVersion() {
            let json = #"{"jsonrpc":"1.0","method":"chats.list","id":1}"#
            #expect(throws: (any Error).self) {
                try JSONRPCProtocol.parseRequest(Data(json.utf8))
            }
        }

        @Test("Reject missing method")
        func rejectMissingMethod() {
            let json = #"{"jsonrpc":"2.0","id":1}"#
            #expect(throws: (any Error).self) {
                try JSONRPCProtocol.parseRequest(Data(json.utf8))
            }
        }

        @Test("Reject invalid JSON")
        func rejectInvalidJSON() {
            #expect(throws: (any Error).self) {
                try JSONRPCProtocol.parseRequest(Data("not json".utf8))
            }
        }
    }

    @Suite("Response Serialization")
    struct ResponseSerializationTests {

        @Test("Serialize success response")
        func serializeSuccessResponse() throws {
            let response = JSONRPCResponse(
                result: ["key": "value"],
                error: nil,
                id: .int(1)
            )
            let data = try JSONRPCProtocol.serializeResponse(response)
            let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            #expect(obj["jsonrpc"] as? String == "2.0")
            #expect(obj["error"] == nil)
            let result = obj["result"] as? [String: Any]
            #expect(result?["key"] as? String == "value")
            #expect(obj["id"] as? Int == 1)
        }

        @Test("Serialize error response")
        func serializeErrorResponse() throws {
            let response = JSONRPCResponse(
                result: nil,
                error: JSONRPCError(code: RPCErrorCode.methodNotFound.rawValue, message: "Method not found"),
                id: .int(1)
            )
            let data = try JSONRPCProtocol.serializeResponse(response)
            let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            #expect(obj["jsonrpc"] as? String == "2.0")
            #expect(obj["result"] == nil)
            let error = obj["error"] as? [String: Any]
            #expect(error?["code"] as? Int == -32601)
            #expect(error?["message"] as? String == "Method not found")
        }

        @Test("Serialize response with string id")
        func serializeStringIdResponse() throws {
            let response = JSONRPCResponse(
                result: ["ok": true],
                error: nil,
                id: .string("req-xyz")
            )
            let data = try JSONRPCProtocol.serializeResponse(response)
            let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            #expect(obj["id"] as? String == "req-xyz")
        }

        @Test("Serialize notification (no id)")
        func serializeNotification() throws {
            let notification = JSONRPCNotification(method: "watch.message", params: ["text": "hello"])
            let data = try JSONRPCProtocol.serializeNotification(notification)
            let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            #expect(obj["jsonrpc"] as? String == "2.0")
            #expect(obj["method"] as? String == "watch.message")
            #expect(obj["id"] == nil)
            let params = obj["params"] as? [String: Any]
            #expect(params?["text"] as? String == "hello")
        }
    }

    @Suite("Error Codes")
    struct ErrorCodeTests {

        @Test("Standard error code values")
        func standardErrorCodes() {
            #expect(RPCErrorCode.parseError.rawValue == -32700)
            #expect(RPCErrorCode.invalidRequest.rawValue == -32600)
            #expect(RPCErrorCode.methodNotFound.rawValue == -32601)
            #expect(RPCErrorCode.invalidParams.rawValue == -32602)
            #expect(RPCErrorCode.internalError.rawValue == -32603)
        }

        @Test("Create errorResponse helper")
        func errorResponseHelper() throws {
            let data = try JSONRPCProtocol.errorResponse(code: .invalidRequest, id: .int(5))
            let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            let error = obj["error"] as? [String: Any]
            #expect(error?["code"] as? Int == -32600)
            #expect(obj["id"] as? Int == 5)
        }
    }
}
