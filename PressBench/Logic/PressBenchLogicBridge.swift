import Foundation
import JavaScriptCore

/// Native boundary around the deterministic PressBench v0.21.4 JavaScript engine.
/// All domain/process/entitlement decisions flow through this bridge. SwiftUI owns
/// presentation only; it never re-implements capacity, proof, run, report or purchase rules.
@MainActor
final class PressBenchLogicBridge {
    enum BridgeError: LocalizedError {
        case resourceMissing
        case contextFailure
        case javascript(String)
        case encoding
        case unexpectedResult(String)

        var errorDescription: String? {
            switch self {
            case .resourceMissing: return "PressBench deterministic engine is missing."
            case .contextFailure: return "PressBench deterministic engine could not start."
            case .javascript(let value): return value
            case .encoding: return "PressBench engine serialization failed."
            case .unexpectedResult(let value): return "Unexpected PressBench engine result: \(value)"
            }
        }
    }

    private let context: JSContext

    init(bundle: Bundle = .main) throws {
        guard let context = JSContext() else { throw BridgeError.contextFailure }
        self.context = context
        context.exceptionHandler = { _, exception in
            if let exception { NSLog("PressBench JS exception: %@", exception.toString() ?? "unknown") }
        }
        context.setObject(["language": Locale.current.identifier], forKeyedSubscript: "navigator" as NSString)

        guard let url = bundle.url(forResource: "PressBenchLogic", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            throw BridgeError.resourceMissing
        }
        context.evaluateScript(source)
        try throwIfException()

        let requiredNamespaces = ["PressBenchDomain", "PressBenchBusiness", "PressBenchEntitlement", "PressBenchProcess"]
        for namespace in requiredNamespaces {
            guard context.objectForKeyedSubscript(namespace) != nil,
                  !context.objectForKeyedSubscript(namespace).isUndefined else {
                throw BridgeError.unexpectedResult("missing \(namespace)")
            }
        }
    }

    func domain(_ function: String, _ arguments: [Any] = []) throws -> Any {
        try call(namespace: "PressBenchDomain", function: function, arguments: arguments)
    }

    func business(_ function: String, _ arguments: [Any] = []) throws -> Any {
        try call(namespace: "PressBenchBusiness", function: function, arguments: arguments)
    }

    func entitlement(_ function: String, _ arguments: [Any] = []) throws -> Any {
        try call(namespace: "PressBenchEntitlement", function: function, arguments: arguments)
    }

    func process(_ function: String, _ arguments: [Any] = []) throws -> Any {
        try call(namespace: "PressBenchProcess", function: function, arguments: arguments)
    }

    func dictionary(_ value: Any, context: String) throws -> [String: Any] {
        guard let result = value as? [String: Any] else { throw BridgeError.unexpectedResult(context) }
        return result
    }

    func dictionaries(_ value: Any, context: String) throws -> [[String: Any]] {
        guard let result = value as? [[String: Any]] else { throw BridgeError.unexpectedResult(context) }
        return result
    }

    private func call(namespace: String, function: String, arguments: [Any]) throws -> Any {
        let data = try JSONSerialization.data(withJSONObject: arguments, options: [.sortedKeys])
        guard let json = String(data: data, encoding: .utf8) else { throw BridgeError.encoding }
        let script = "JSON.stringify(\(namespace).\(function).apply(null, JSON.parse(\(quoted(json)))))"
        guard let encoded = context.evaluateScript(script)?.toString() else {
            try throwIfException()
            throw BridgeError.unexpectedResult("\(namespace).\(function)")
        }
        try throwIfException()
        guard let output = encoded.data(using: .utf8) else { throw BridgeError.encoding }
        return try JSONSerialization.jsonObject(with: output, options: [.fragmentsAllowed])
    }

    private func throwIfException() throws {
        if let exception = context.exception {
            let text = exception.toString() ?? "javascript_error"
            context.exception = nil
            throw BridgeError.javascript(text)
        }
    }

    private func quoted(_ value: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [value], options: [])
        let json = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        return String(json.dropFirst().dropLast())
    }
}
