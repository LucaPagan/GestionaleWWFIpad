import Foundation
import CoreLocation

struct PolylineCodec {
    static func encode(_ coordinates: [CLLocationCoordinate2D]) -> String {
        var lastLat = 0
        var lastLng = 0
        var result = ""

        for coord in coordinates {
            let lat = Int(round(coord.latitude * 1e5))
            let lng = Int(round(coord.longitude * 1e5))

            result += encodeValue(lat - lastLat)
            result += encodeValue(lng - lastLng)

            lastLat = lat
            lastLng = lng
        }
        return result
    }

    private static func encodeValue(_ value: Int) -> String {
        var v = value < 0 ? ~(value << 1) : (value << 1)
        var result = ""
        while v >= 0x20 {
            result += String(UnicodeScalar((0x20 | (v & 0x1f)) + 63)!)
            v >>= 5
        }
        result += String(UnicodeScalar(v + 63)!)
        return result
    }

    static func decode(_ encoded: String) -> [CLLocationCoordinate2D] {
        var coordinates = [CLLocationCoordinate2D]()
        var index = encoded.startIndex
        var lat = 0
        var lng = 0

        while index < encoded.endIndex {
            lat += decodeValue(encoded: encoded, index: &index)
            lng += decodeValue(encoded: encoded, index: &index)
            coordinates.append(CLLocationCoordinate2D(latitude: Double(lat) / 1e5, longitude: Double(lng) / 1e5))
        }
        return coordinates
    }

    private static func decodeValue(encoded: String, index: inout String.Index) -> Int {
        var result = 0
        var shift = 0
        var byte: Int
        repeat {
            if index >= encoded.endIndex { break }
            byte = Int(encoded[index].unicodeScalars.first!.value) - 63
            index = encoded.index(after: index)
            result |= (byte & 0x1f) << shift
            shift += 5
        } while byte >= 0x20
        return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
    }
}

let coords = [
    CLLocationCoordinate2D(latitude: 0.12345, longitude: 0.54321),
    CLLocationCoordinate2D(latitude: 0.12350, longitude: 0.54325)
]
let enc = PolylineCodec.encode(coords)
print("Encoded: \(enc)")
let dec = PolylineCodec.decode(enc)
print("Decoded: \(dec.map { "(\($0.latitude), \($0.longitude))" }.joined(separator: ", "))")
