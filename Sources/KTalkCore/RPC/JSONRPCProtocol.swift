import Foundation

// MARK: - Types

public enum JSONRPCRequestID: Equatable, Sendable {
    case int(Int)
    case string(String)
}

public struct JSONRPCRequest: @unchecked Sendable {
    public let jsonrpc: String
    public let method: String
    public let params: [String: Any]?
    public let id: JSONRPCRequestID?

    public init(jsonrpc: String, method: String, params: [String: Any]?, id: JSONRPCRequestID?) {
        self.jsonrpc = jsonrpc
        self.method = method
        self.params = params
        self.id = id
    }
}

public struct JSONRPCResponse: @unchecked Sendable {
    public let result: Any?
    public let error: JSONRPCError?
    public let id: JSONRPCRequestID?

    public init(result: Any?, error: JSONRPCError?, id: JSONRPCRequestID?) {
        self.result = result
        self.error = error
        self.id = id
    }
}

public struct JSONRPCNotification: @unchecked Sendable {
    public let method: String
    public let params: [String: Any]?

    public init(method: String, params: [String: Any]?) {
        self.method = method
        self.params = params
    }
}

public struct JSONRPCError: Sendable {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
}

public enum RPCErrorCode: Int, Sendable {
    case parseError     = -32700
    case invalidRequest = -32600
    case methodNotFound = -32601
    case invalidParams  = -32602
    case internalError  = -32603

    var defaultMessage: String {
        switch self {
        case .parseError:     return "Parse error"
        case .invalidRequest: return "Invalid Request"
        case .methodNotFound: return "Method not found"
        case .invalidParams:  return "Invalid params"
        case .internalError:  return "Internal error"
        }
    }
}

public enum JSONRPCParseError: Error, Sendable {
    case invalidJSON
    case invalidVersion
    case missingMethod
}

// MARK: - Protocol helpers

public enum JSONRPCProtocol {

    /// Parses Data as a JSON-RPC 2.0 request.
    public static func parseRequest(_ data: Data) throws -> JSONRPCRequest {
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any] else {
            throw JSONRPCParseError.invalidJSON
        }

        guard let jsonrpc = dict["jsonrpc"] as? String, jsonrpc == "2.0" else {
            throw JSONRPCParseError.invalidVersion
        }

        guard let method = dict["method"] as? String else {
            throw JSONRPCParseError.missingMethod
        }

        let params = dict["params"] as? [String: Any]

        let id: JSONRPCRequestID?
        if let v = dict["id"] as? Int {
            id = .int(v)
        } else if let v = dict["id"] as? String {
            id = .string(v)
        } else {
            id = nil
        }

        return JSONRPCRequest(jsonrpc: jsonrpc, method: method, params: params, id: id)
    }

    /// Serializes a JSON-RPC 2.0 response to Data.
    public static func serializeResponse(_ response: JSONRPCResponse) throws -> Data {
        var dict: [String: Any] = ["jsonrpc": "2.0"]

        if let error = response.error {
            dict["error"] = ["code": error.code, "message": error.message]
        } else if let result = response.result {
            dict["result"] = result
        } else {
            dict["result"] = NSNull()
        }

        switch response.id {
        case .int(let v):    dict["id"] = v
        case .string(let v): dict["id"] = v
        case nil:            break
        }

        return try JSONSerialization.data(withJSONObject: dict)
    }

    /// Serializes a JSON-RPC 2.0 notification to Data (no id, server→client).
    public static func serializeNotification(_ notification: JSONRPCNotification) throws -> Data {
        var dict: [String: Any] = [
            "jsonrpc": "2.0",
            "method": notification.method,
        ]
        if let params = notification.params {
            dict["params"] = params
        }
        return try JSONSerialization.data(withJSONObject: dict)
    }

    /// Generates an error response Data using a standard error code.
    public static func errorResponse(code: RPCErrorCode, id: JSONRPCRequestID?) throws -> Data {
        let response = JSONRPCResponse(
            result: nil,
            error: JSONRPCError(code: code.rawValue, message: code.defaultMessage),
            id: id
        )
        return try serializeResponse(response)
    }
}
