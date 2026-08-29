import XCTest
@testable import Chameo

final class LiveFramingGuidanceTests: XCTestCase {
    private let previewSize = CGSize(width: 392, height: 322)

    func testAspectFillGeometryAccountsForHorizontalCrop() throws {
        let face = try XCTUnwrap(
            LiveFramingGeometry.face(
                from: LiveFramingFaceObservation(
                    boundingBox: CGRect(x: 0.4, y: 0.3, width: 0.2, height: 0.4),
                    eyeLineY: 0.55
                ),
                framePixelWidth: 1920,
                framePixelHeight: 1080,
                previewSize: previewSize,
                mirrored: false
            )
        )

        XCTAssertEqual(face.boundingBox.midX, previewSize.width / 2, accuracy: 0.001)
        XCTAssertGreaterThan(face.boundingBox.width, previewSize.width * 0.2)
    }

    func testMirroringReflectsFaceAcrossPreviewCenter() throws {
        let observation = LiveFramingFaceObservation(
            boundingBox: CGRect(x: 0.15, y: 0.3, width: 0.2, height: 0.4),
            eyeLineY: 0.55
        )
        let unmirrored = try XCTUnwrap(
            LiveFramingGeometry.face(
                from: observation,
                framePixelWidth: 1280,
                framePixelHeight: 720,
                previewSize: previewSize,
                mirrored: false
            )
        )
        let mirrored = try XCTUnwrap(
            LiveFramingGeometry.face(
                from: observation,
                framePixelWidth: 1280,
                framePixelHeight: 720,
                previewSize: previewSize,
                mirrored: true
            )
        )

        XCTAssertEqual(
            unmirrored.boundingBox.midX + mirrored.boundingBox.midX,
            previewSize.width,
            accuracy: 0.001
        )
    }

    func testNoFaceDebouncesToCenterHint() {
        var evaluator = LiveFramingGuidanceEvaluator()
        let frame = LiveFramingFrame(pixelWidth: 1280, pixelHeight: 720, faces: [])

        XCTAssertEqual(
            evaluator.evaluate(frame: frame, previewSize: previewSize, mirrored: true),
            .neutral
        )
        XCTAssertEqual(
            evaluator.evaluate(frame: frame, previewSize: previewSize, mirrored: true),
            .neutral
        )
        XCTAssertEqual(
            evaluator.evaluate(frame: frame, previewSize: previewSize, mirrored: true),
            .adjusting(.centerFace)
        )
    }

    func testMultipleFacesTakePriority() {
        var evaluator = LiveFramingGuidanceEvaluator()
        let face = observation(
            previewCenterX: previewSize.width / 2,
            previewWidth: targetFaceWidth
        )
        let frame = LiveFramingFrame(
            pixelWidth: Int(previewSize.width),
            pixelHeight: Int(previewSize.height),
            faces: [face, face]
        )

        XCTAssertEqual(stabilizedState(&evaluator, frame: frame), .adjusting(.onePerson))
    }

    func testDistanceHintsTakePriorityOverCentering() {
        var evaluator = LiveFramingGuidanceEvaluator()
        let smallFace = observation(
            previewCenterX: previewSize.width * 0.2,
            previewWidth: targetFaceWidth * 0.5
        )
        let frame = directFrame(face: smallFace)

        XCTAssertEqual(stabilizedState(&evaluator, frame: frame), .adjusting(.moveCloser))
    }

    func testOversizedFaceProducesMoveBackHint() {
        var evaluator = LiveFramingGuidanceEvaluator()
        let frame = directFrame(
            face: observation(
                previewCenterX: previewSize.width / 2,
                previewWidth: targetFaceWidth * 1.7
            )
        )

        XCTAssertEqual(stabilizedState(&evaluator, frame: frame), .adjusting(.moveBack))
    }

    func testCloserFaceCanStillBecomeReady() {
        var evaluator = LiveFramingGuidanceEvaluator()
        let frame = directFrame(
            face: observation(
                previewCenterX: previewSize.width / 2,
                previewWidth: targetFaceWidth * 1.35
            )
        )

        var state = LiveFramingGuidanceState.neutral
        for _ in 0..<5 {
            state = evaluator.evaluate(
                frame: frame,
                previewSize: previewSize,
                mirrored: false
            )
        }
        XCTAssertEqual(state, .ready)
    }

    func testOffCenterFaceProducesCenteringHint() {
        var evaluator = LiveFramingGuidanceEvaluator()
        let frame = directFrame(
            face: observation(
                previewCenterX: previewSize.width / 2 + previewSize.width * 0.1,
                previewWidth: targetFaceWidth
            )
        )

        XCTAssertEqual(
            stabilizedState(&evaluator, frame: frame),
            .adjusting(.moveTowardCenter)
        )
    }

    func testLowEyeLineProducesMoveHigherHint() {
        var evaluator = LiveFramingGuidanceEvaluator()
        let frame = directFrame(
            face: observation(
                previewCenterX: previewSize.width / 2,
                previewWidth: targetFaceWidth,
                eyeLineOffset: previewSize.height * 0.1
            )
        )

        XCTAssertEqual(stabilizedState(&evaluator, frame: frame), .adjusting(.moveHigher))
    }

    func testHighEyeLineProducesMoveLowerHint() {
        var evaluator = LiveFramingGuidanceEvaluator()
        let frame = directFrame(
            face: observation(
                previewCenterX: previewSize.width / 2,
                previewWidth: targetFaceWidth,
                eyeLineOffset: -previewSize.height * 0.1
            )
        )

        XCTAssertEqual(stabilizedState(&evaluator, frame: frame), .adjusting(.moveLower))
    }

    func testCenteredFaceBecomesReadyAfterFourStableSamples() {
        var evaluator = LiveFramingGuidanceEvaluator()
        let frame = directFrame(
            face: observation(
                previewCenterX: previewSize.width / 2,
                previewWidth: targetFaceWidth
            )
        )

        XCTAssertEqual(
            evaluator.evaluate(frame: frame, previewSize: previewSize, mirrored: false),
            .neutral
        )
        XCTAssertEqual(
            evaluator.evaluate(frame: frame, previewSize: previewSize, mirrored: false),
            .neutral
        )
        XCTAssertEqual(
            evaluator.evaluate(frame: frame, previewSize: previewSize, mirrored: false),
            .neutral
        )
        XCTAssertEqual(
            evaluator.evaluate(frame: frame, previewSize: previewSize, mirrored: false),
            .neutral
        )
        XCTAssertEqual(
            evaluator.evaluate(frame: frame, previewSize: previewSize, mirrored: false),
            .ready
        )
    }

    func testMovementProducesHoldStill() {
        var evaluator = LiveFramingGuidanceEvaluator()
        let left = directFrame(
            face: observation(
                previewCenterX: previewSize.width / 2 - 4,
                previewWidth: targetFaceWidth
            )
        )
        let right = directFrame(
            face: observation(
                previewCenterX: previewSize.width / 2 + 4,
                previewWidth: targetFaceWidth
            )
        )

        for index in 0..<5 {
            _ = evaluator.evaluate(
                frame: index.isMultiple(of: 2) ? left : right,
                previewSize: previewSize,
                mirrored: false
            )
        }

        XCTAssertEqual(
            evaluator.evaluate(frame: right, previewSize: previewSize, mirrored: false),
            .adjusting(.holdStill)
        )
    }

    func testCountdownRetainsReadyForSlightMovementButCancelsForMissingFace() {
        var evaluator = LiveFramingGuidanceEvaluator()
        var countdown = HandsFreeCountdownMachine()
        _ = countdown.handle(.setVisible(true))
        _ = countdown.handle(.setEnabled(true))

        let centered = directFrame(
            face: observation(
                previewCenterX: previewSize.width / 2,
                previewWidth: targetFaceWidth
            )
        )
        for _ in 0..<5 {
            let guidance = evaluator.evaluate(
                frame: centered,
                previewSize: previewSize,
                mirrored: false
            )
            _ = countdown.handle(.guidanceChanged(guidance))
        }
        XCTAssertEqual(countdown.phase, .counting(3))

        let slightlyMoved = directFrame(
            face: observation(
                previewCenterX: previewSize.width / 2 + 8,
                previewWidth: targetFaceWidth
            )
        )
        let guidance = evaluator.evaluate(
            frame: slightlyMoved,
            previewSize: previewSize,
            mirrored: false
        )

        XCTAssertEqual(guidance, .ready)
        XCTAssertEqual(countdown.handle(.guidanceChanged(guidance)), [])
        XCTAssertEqual(countdown.phase, .counting(3))

        let missingFaceGuidance = evaluator.evaluate(
            frame: LiveFramingFrame(
                pixelWidth: Int(previewSize.width),
                pixelHeight: Int(previewSize.height),
                faces: []
            ),
            previewSize: previewSize,
            mirrored: false
        )

        XCTAssertEqual(missingFaceGuidance, .neutral)
        XCTAssertEqual(
            countdown.handle(.guidanceChanged(missingFaceGuidance)),
            [.cancelTimer]
        )
        XCTAssertEqual(countdown.phase, .armed)
    }

    func testResetReturnsEvaluatorToNeutral() {
        var evaluator = LiveFramingGuidanceEvaluator()
        let frame = LiveFramingFrame(pixelWidth: 1280, pixelHeight: 720, faces: [])
        _ = stabilizedState(&evaluator, frame: frame)

        XCTAssertEqual(evaluator.reset(), .neutral)
        XCTAssertEqual(
            evaluator.evaluate(frame: frame, previewSize: previewSize, mirrored: true),
            .neutral
        )
    }

    private var targetFaceWidth: CGFloat {
        FaceGuideGeometry.rect(in: previewSize).width * 0.72
    }

    private func directFrame(face: LiveFramingFaceObservation) -> LiveFramingFrame {
        LiveFramingFrame(
            pixelWidth: Int(previewSize.width),
            pixelHeight: Int(previewSize.height),
            faces: [face]
        )
    }

    private func observation(
        previewCenterX: CGFloat,
        previewWidth: CGFloat,
        eyeLineOffset: CGFloat = 0
    ) -> LiveFramingFaceObservation {
        let guide = FaceGuideGeometry.rect(in: previewSize)
        let targetEyeLine = FaceGuideGeometry.eyeLineY(in: previewSize) + eyeLineOffset
        let height = guide.height * 0.72
        let originY = targetEyeLine - height * 0.38
        let previewRect = CGRect(
            x: previewCenterX - previewWidth / 2,
            y: originY,
            width: previewWidth,
            height: height
        )

        return LiveFramingFaceObservation(
            boundingBox: CGRect(
                x: previewRect.minX / previewSize.width,
                y: 1 - previewRect.maxY / previewSize.height,
                width: previewRect.width / previewSize.width,
                height: previewRect.height / previewSize.height
            ),
            eyeLineY: 1 - targetEyeLine / previewSize.height
        )
    }

    private func stabilizedState(
        _ evaluator: inout LiveFramingGuidanceEvaluator,
        frame: LiveFramingFrame
    ) -> LiveFramingGuidanceState {
        var state = LiveFramingGuidanceState.neutral
        for _ in 0..<4 {
            state = evaluator.evaluate(
                frame: frame,
                previewSize: previewSize,
                mirrored: false
            )
        }
        return state
    }
}
