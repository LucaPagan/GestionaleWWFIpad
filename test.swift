import Foundation

let dict: [String: Any?] = ["path_geometry": nil, "valid": "hello"]
for key in dict.keys {
    let val = dict[key] as Any?
    let display = Mirror(reflecting: val).displayStyle
    print("\(key): \(String(describing: val)) - \(String(describing: display))")
}
