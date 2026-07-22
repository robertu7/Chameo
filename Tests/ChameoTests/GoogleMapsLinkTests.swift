import CoreLocation
import XCTest

@testable import Chameo

final class GoogleMapsLinkTests: XCTestCase {
    func testURLTargetsThePhotoCoordinateInGoogleMaps() throws {
        let location = CLLocation(latitude: 37.334925306700406, longitude: -122.00825316523328)

        let url = try XCTUnwrap(GoogleMapsLink.url(for: location))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "www.google.com")
        XCTAssertEqual(components.path, "/maps/search/")
        XCTAssertEqual(
            components.queryItems,
            [
                URLQueryItem(name: "api", value: "1"),
                URLQueryItem(name: "query", value: "37.334925306700406,-122.00825316523328"),
            ]
        )
    }
}
