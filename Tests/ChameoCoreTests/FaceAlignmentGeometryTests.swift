import XCTest
@testable import ChameoCore

final class FaceAlignmentGeometryTests: XCTestCase {
    func testHorizontalEyesDoNotRotate() throws {
        let plan = try FaceAlignmentGeometry.plan(
            for: FaceAlignmentGeometry.Input(
                imageSize: CGSize(width: 1600, height: 1200),
                leftEye: CGPoint(x: 600, y: 740),
                rightEye: CGPoint(x: 1000, y: 740),
                nose: CGPoint(x: 800, y: 600),
                mouth: CGPoint(x: 800, y: 470)
            )
        )

        XCTAssertEqual(plan.rotationRadians, 0, accuracy: 0.0001)
    }

    func testTiltedEyesProduceCorrectiveRotation() throws {
        let plan = try FaceAlignmentGeometry.plan(
            for: FaceAlignmentGeometry.Input(
                imageSize: CGSize(width: 1600, height: 1200),
                leftEye: CGPoint(x: 600, y: 700),
                rightEye: CGPoint(x: 1000, y: 800),
                nose: CGPoint(x: 800, y: 600),
                mouth: CGPoint(x: 800, y: 470)
            )
        )

        XCTAssertLessThan(plan.rotationRadians, 0)
        XCTAssertEqual(plan.rotationRadians, -atan2(100, 400), accuracy: 0.0001)
    }

    func testOutputIsSquareAndAnchorsFace() throws {
        let plan = try FaceAlignmentGeometry.plan(
            for: FaceAlignmentGeometry.Input(
                imageSize: CGSize(width: 1600, height: 1200),
                leftEye: CGPoint(x: 620, y: 740),
                rightEye: CGPoint(x: 980, y: 740),
                nose: CGPoint(x: 800, y: 610),
                mouth: CGPoint(x: 800, y: 480)
            )
        )

        XCTAssertEqual(plan.outputSize.width, plan.outputSize.height)
        XCTAssertEqual(plan.outputSize.width, FaceAlignmentGeometry.outputLength)
        XCTAssertEqual(plan.scale, (FaceAlignmentGeometry.outputLength * 0.20) / 360, accuracy: 0.0001)
        XCTAssertEqual(plan.anchor.applying(plan.transform).x, plan.targetAnchor.x, accuracy: 0.0001)
        XCTAssertEqual(plan.anchor.applying(plan.transform).y, plan.targetAnchor.y, accuracy: 0.0001)
    }
}
