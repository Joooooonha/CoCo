import CoreLocation
import Foundation

struct GPXRoute {
    let name: String?
    let coordinates: [CLLocationCoordinate2D]
    let distanceMeters: Int?
    let durationSeconds: Int?
}

enum GPXParseError: LocalizedError {
    case invalidDocument
    case notEnoughTrackPoints

    var errorDescription: String? {
        switch self {
        case .invalidDocument:
            "GPX 파일을 읽을 수 없어요. 파일 형식을 확인해 주세요."
        case .notEnoughTrackPoints:
            "GPX 파일에 경로 지점이 부족해요. 트랙 지점이 2개 이상 필요해요."
        }
    }
}

/// Parses GPX 1.1 track data. Reads `trkpt` coordinates in document order and,
/// when present, the Naver Map `walkCourse` distance and duration extensions.
final class GPXParser: NSObject, XMLParserDelegate {
    private var coordinates: [CLLocationCoordinate2D] = []
    private var routeName: String?
    private var distanceMeters: Int?
    private var durationSeconds: Int?
    private var elementPath: [String] = []
    private var currentText = ""

    static func parse(data: Data) throws -> GPXRoute {
        let parser = GPXParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser

        guard xmlParser.parse() else {
            throw GPXParseError.invalidDocument
        }
        guard parser.coordinates.count >= 2 else {
            throw GPXParseError.notEnoughTrackPoints
        }
        return GPXRoute(
            name: parser.routeName,
            coordinates: parser.coordinates,
            distanceMeters: parser.distanceMeters,
            durationSeconds: parser.durationSeconds
        )
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        elementPath.append(elementName)
        currentText = ""

        if elementName == "trkpt",
           let latitude = attributes["lat"].flatMap(Double.init),
           let longitude = attributes["lon"].flatMap(Double.init),
           (-90...90).contains(latitude),
           (-180...180).contains(longitude) {
            coordinates.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        defer { elementPath.removeLast() }
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "name" where elementPath.dropLast().last == "metadata":
            routeName = text.isEmpty ? nil : text
        case let element where element.hasSuffix("distance"):
            if let value = Double(text), value > 0 {
                distanceMeters = Int(value.rounded())
            }
        case let element where element.hasSuffix("duration"):
            if let value = Double(text), value > 0 {
                durationSeconds = Int(value.rounded())
            }
        default:
            break
        }
        currentText = ""
    }
}
