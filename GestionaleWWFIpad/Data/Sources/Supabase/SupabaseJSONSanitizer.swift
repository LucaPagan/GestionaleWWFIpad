//
//  SupabaseJSONSanitizer.swift
//  GestionaleWWFIpad
//
//  Costruisce payload JSON con tipi Swift nativi (no NSMutableDictionary / NSString bridge).
//

import Foundation

enum SupabaseJSONSanitizer {

    static func data(from params: [String: Any?]) throws -> Data {
        let object = object(from: params)
        guard JSONSerialization.isValidJSONObject(object) else {
            throw SupabaseError.apiError("Payload JSON non serializzabile")
        }
        return try JSONSerialization.data(withJSONObject: object)
    }

    static func object(from params: [String: Any?]) -> [String: Any] {
        var result = [String: Any]()
        result.reserveCapacity(params.count)
        for key in params.keys {
            result[key] = jsonValue(params[key] as Any?)
        }
        return result
    }

    static func jsonValue(_ value: Any?) -> Any {
        guard let value else { return NSNull() }

        if isSwiftOptional(value) {
            guard let unwrapped = unwrapSwiftOptional(value) else { return NSNull() }
            return jsonValue(unwrapped as Any?)
        }

        switch value {
        case let string as String:
            return copyString(string)
        case let bool as Bool:
            return bool
        case let int as Int:
            return int
        case let int64 as Int64:
            return int64
        case let int32 as Int32:
            return int32
        case let uint as UInt:
            return uint
        case let double as Double:
            return double
        case let float as Float:
            return Double(float)
        case let number as NSNumber:
            return number
        case is NSNull:
            return NSNull()
        case let uuid as UUID:
            return copyString(uuid.uuidString)
        case let date as Date:
            return copyString(ISO8601DateFormatter().string(from: date))
        case let dict as [String: Any?]:
            return object(from: dict)
        case let dict as [String: Any]:
            return dict.mapValues { jsonValue($0 as Any?) }
        case let dict as NSDictionary:
            var result = [String: Any]()
            for key in dict.allKeys {
                guard let keyString = key as? String else { continue }
                result[copyString(keyString)] = jsonValue(dict[key] as Any?)
            }
            return result
        case let array as [Any]:
            return array.map { jsonValue($0 as Any?) }
        case let array as [Any?]:
            return array.map { jsonValue($0 as Any?) }
        case let array as NSArray:
            return (0..<array.count).map { jsonValue(array[$0] as Any?) }
        case let set as Set<String>:
            return set.sorted().map { copyString($0) }
        case is Data:
            return NSNull()
        default:
            return copyString(String(describing: value))
        }
    }

    private static func copyString(_ string: String) -> String {
        "\(string)"
    }

    private static func isSwiftOptional(_ value: Any) -> Bool {
        Mirror(reflecting: value).displayStyle == .optional
    }

    private static func unwrapSwiftOptional(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else { return value }
        return mirror.children.first?.value
    }
}
