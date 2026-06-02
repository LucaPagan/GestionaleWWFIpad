import Foundation

// Simulate JSON Serialization
let dict: [String: Any] = ["path_geometry": "_p~iF~ps|U_ulLnnqC_mqNvxq`@"]
let data = try! JSONSerialization.data(withJSONObject: dict)
let str = String(data: data, encoding: .utf8)!
print("JSON: \(str)")
