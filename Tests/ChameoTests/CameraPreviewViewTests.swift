import AVFoundation
import CoreGraphics
import XCTest
@testable import Chameo

@MainActor
final class CameraPreviewViewTests: XCTestCase {
    func testMirrorPreferenceIsAppliedWhenConnectionAlreadyExists() throws {
        let session = AVCaptureSession()
        let view = PreviewView()
        view.previewLayer.session = session
        let input = try XCTUnwrap(AVCaptureScreenInput(displayID: CGMainDisplayID()))
        session.addInput(input)
        let connection = try XCTUnwrap(view.previewLayer.connection)

        view.setMirrored(true)
        XCTAssertTrue(connection.isVideoMirrored)
        XCTAssertFalse(connection.automaticallyAdjustsVideoMirroring)
        view.setMirrored(false)
        XCTAssertFalse(connection.isVideoMirrored)
    }

    func testInitialMirrorPreferenceIsAppliedWhenConnectionAppears() async throws {
        let session = AVCaptureSession()
        let view = PreviewView()
        defer { withExtendedLifetime(view) {} }
        view.previewLayer.session = session
        XCTAssertNil(view.previewLayer.connection)

        // The view mounts before CameraSessionController configures its input.
        view.setMirrored(true)
        let input = try XCTUnwrap(AVCaptureScreenInput(displayID: CGMainDisplayID()))
        XCTAssertTrue(session.canAddInput(input))
        session.beginConfiguration()
        session.addInput(input)
        session.commitConfiguration()
        let connection = try XCTUnwrap(view.previewLayer.connection)
        XCTAssertTrue(connection.isVideoMirroringSupported)

        // A screen input gives us a real video connection without starting capture
        // or requiring a physical camera. No further SwiftUI update is performed.
        try await waitForMirroring(true, on: connection)
    }

    private func waitForMirroring(_ mirrored: Bool, on connection: AVCaptureConnection) async throws {
        for _ in 0..<100 {
            if connection.isVideoMirrored == mirrored && !connection.automaticallyAdjustsVideoMirroring {
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertEqual(connection.isVideoMirrored, mirrored)
        XCTAssertFalse(connection.automaticallyAdjustsVideoMirroring)
    }
}
