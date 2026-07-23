import CoreLocation
import Foundation
import Testing
@testable import CoCo

struct GPXParserTests {
    @Test
    func parsesNaverStyleTrackWithExtensions() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="네이버지도" xmlns="http://www.topografix.com/GPX/1/1" xmlns:nmap="https://map.naver.com/gpx/1">
          <metadata>
            <name>남산 산책</name>
            <extensions>
              <nmap:walkCourse schemaVersion="1.0">
                <nmap:distance>4455</nmap:distance>
                <nmap:duration>5194.2</nmap:duration>
              </nmap:walkCourse>
            </extensions>
          </metadata>
          <trk>
            <trkseg>
              <trkpt lat="37.5611" lon="126.9892"></trkpt>
              <trkpt lat="37.5601" lon="126.9902"></trkpt>
              <trkpt lat="37.5591" lon="126.9912"></trkpt>
            </trkseg>
          </trk>
        </gpx>
        """

        let route = try GPXParser.parse(data: Data(gpx.utf8))

        #expect(route.name == "남산 산책")
        #expect(route.coordinates.count == 3)
        #expect(route.coordinates.first?.latitude == 37.5611)
        #expect(route.coordinates.last?.longitude == 126.9912)
        #expect(route.distanceMeters == 4455)
        #expect(route.durationSeconds == 5194)
    }

    @Test
    func parsesPlainTrackWithoutExtensions() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
          <trk><trkseg>
            <trkpt lat="37.5" lon="127.0"></trkpt>
            <trkpt lat="37.6" lon="127.1"></trkpt>
          </trkseg></trk>
        </gpx>
        """

        let route = try GPXParser.parse(data: Data(gpx.utf8))

        #expect(route.name == nil)
        #expect(route.coordinates.count == 2)
        #expect(route.distanceMeters == nil)
        #expect(route.durationSeconds == nil)
    }

    @Test
    func rejectsInvalidXML() {
        #expect(throws: GPXParseError.invalidDocument) {
            _ = try GPXParser.parse(data: Data("not xml at all".utf8))
        }
    }

    @Test
    func rejectsSingleTrackPoint() {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1"><trk><trkseg>
          <trkpt lat="37.5" lon="127.0"></trkpt>
        </trkseg></trk></gpx>
        """

        #expect(throws: GPXParseError.notEnoughTrackPoints) {
            _ = try GPXParser.parse(data: Data(gpx.utf8))
        }
    }

    @Test
    func skipsOutOfRangeCoordinates() throws {
        let gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1"><trk><trkseg>
          <trkpt lat="37.5" lon="127.0"></trkpt>
          <trkpt lat="95.0" lon="127.0"></trkpt>
          <trkpt lat="37.6" lon="200.0"></trkpt>
          <trkpt lat="37.7" lon="127.2"></trkpt>
        </trkseg></trk></gpx>
        """

        let route = try GPXParser.parse(data: Data(gpx.utf8))

        #expect(route.coordinates.count == 2)
    }
}
