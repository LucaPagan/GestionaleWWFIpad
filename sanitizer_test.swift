import Foundation

enum SupabaseJSONSanitizer {
    nonisolated static func data(from params: [String: Any?]) throws -> Data {
        let object = object(from: params)
        guard JSONSerialization.isValidJSONObject(object) else {
            throw NSError(domain: "SupabaseError", code: 1, userInfo: nil)
        }
        return try JSONSerialization.data(withJSONObject: object)
    }

    nonisolated static func object(from params: [String: Any?]) -> [String: Any] {
        var result = [String: Any]()
        result.reserveCapacity(params.count)
        for key in params.keys {
            result[key] = jsonValue(params[key] as Any?)
        }
        return result
    }

    nonisolated static func jsonValue(_ value: Any?) -> Any {
        guard let value else { return NSNull() }

        if isSwiftOptional(value) {
            guard let unwrapped = unwrapSwiftOptional(value) else { return NSNull() }
            return jsonValue(unwrapped as Any?)
        }

        switch value {
        case let string as String:
            return copyString(string)
        case is NSNull:
            return NSNull()
        case let dict as [String: Any?]:
            return object(from: dict)
        case let dict as [String: Any]:
            return dict.mapValues { jsonValue($0 as Any?) }
        case let array as [Any]:
            return array.map { jsonValue($0 as Any?) }
        case let array as [Any?]:
            return array.map { jsonValue($0 as Any?) }
        default:
            return copyString(String(describing: value))
        }
    }

    nonisolated private static func copyString(_ string: String) -> String {
        "\(string)"
    }

    nonisolated private static func isSwiftOptional(_ value: Any) -> Bool {
        Mirror(reflecting: value).displayStyle == .optional
    }

    nonisolated private static func unwrapSwiftOptional(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else { return value }
        return mirror.children.first?.value
    }
}

let params: [String: Any?] = [
    "p_path_id": "123",
    "p_steps": [
        [
            "id": "abc",
            "path_geometry": Optional<String>.some("path_geometry_string_\\encoded")
        ]
    ] as [[String: Any?]]
]

let d = try! SupabaseJSONSanitizer.data(from: params)
print(String(data: d, encoding: .utf8)!)
