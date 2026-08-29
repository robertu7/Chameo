import CoreGraphics

enum LiveFramingHint: Equatable, Sendable {
    case centerFace
    case onePerson
    case moveCloser
    case moveBack
    case moveTowardCenter
    case moveHigher
    case moveLower
    case holdStill

    var title: String {
        switch self {
        case .centerFace:
            return L10n.string("Center your face")
        case .onePerson:
            return L10n.string("One person at a time")
        case .moveCloser:
            return L10n.string("Move closer")
        case .moveBack:
            return L10n.string("Move back")
        case .moveTowardCenter:
            return L10n.string("Move toward center")
        case .moveHigher:
            return L10n.string("Move a little higher")
        case .moveLower:
            return L10n.string("Move a little lower")
        case .holdStill:
            return L10n.string("Hold still")
        }
    }
}

enum LiveFramingGuidanceState: Equatable, Sendable {
    case neutral
    case adjusting(LiveFramingHint)
    case ready

    var title: String? {
        switch self {
        case .neutral:
            return nil
        case .adjusting(let hint):
            return hint.title
        case .ready:
            return L10n.string("Ready")
        }
    }
}

struct LiveFramingFaceObservation: Equatable, Sendable {
    /// Vision-normalized bounds with a bottom-left origin.
    let boundingBox: CGRect
    /// Vision-normalized eye-line position with a bottom-left origin.
    let eyeLineY: CGFloat?
}

struct LiveFramingFrame: Equatable, Sendable {
    let pixelWidth: Int
    let pixelHeight: Int
    let faces: [LiveFramingFaceObservation]
}

struct LiveFramingFaceGeometry: Equatable, Sendable {
    let boundingBox: CGRect
    let eyeLineY: CGFloat
}

enum FaceGuideGeometry {
    static func rect(in size: CGSize) -> CGRect {
        let width = min(size.width * 0.48, size.height * 0.42)
        let height = min(size.height * 0.78, width * 1.34)
        let originX = (size.width - width) / 2
        let originY = (size.height - height) / 2

        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    static func eyeLineY(in size: CGSize) -> CGFloat {
        let rect = rect(in: size)
        return rect.minY + rect.height * 0.38
    }
}

enum LiveFramingGeometry {
    static func face(
        from observation: LiveFramingFaceObservation,
        framePixelWidth: Int,
        framePixelHeight: Int,
        previewSize: CGSize,
        mirrored: Bool
    ) -> LiveFramingFaceGeometry? {
        guard framePixelWidth > 0,
              framePixelHeight > 0,
              previewSize.width > 0,
              previewSize.height > 0 else {
            return nil
        }

        let sourceSize = CGSize(width: framePixelWidth, height: framePixelHeight)
        let scale = max(
            previewSize.width / sourceSize.width,
            previewSize.height / sourceSize.height
        )
        let scaledSize = CGSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )
        let cropOffset = CGPoint(
            x: (scaledSize.width - previewSize.width) / 2,
            y: (scaledSize.height - previewSize.height) / 2
        )

        func previewPoint(x: CGFloat, y: CGFloat) -> CGPoint {
            let normalizedX = mirrored ? 1 - x : x
            return CGPoint(
                x: normalizedX * scaledSize.width - cropOffset.x,
                y: (1 - y) * scaledSize.height - cropOffset.y
            )
        }

        let visionRect = observation.boundingBox.standardized
        let topLeft = previewPoint(x: visionRect.minX, y: visionRect.maxY)
        let bottomRight = previewPoint(x: visionRect.maxX, y: visionRect.minY)
        let previewRect = CGRect(
            x: min(topLeft.x, bottomRight.x),
            y: min(topLeft.y, bottomRight.y),
            width: abs(bottomRight.x - topLeft.x),
            height: abs(bottomRight.y - topLeft.y)
        )
        let normalizedEyeLine = observation.eyeLineY
            ?? (visionRect.minY + visionRect.height * 0.62)
        let eyeLineY = previewPoint(
            x: visionRect.midX,
            y: normalizedEyeLine
        ).y

        return LiveFramingFaceGeometry(
            boundingBox: previewRect,
            eyeLineY: eyeLineY
        )
    }
}

struct LiveFramingGuidanceEvaluator {
    private static let smoothingFactor: CGFloat = 0.35
    private static let adjustmentSampleCount = 3
    private static let readySampleCount = 4
    private static let centerTolerance: CGFloat = 0.06
    private static let eyeLineTolerance: CGFloat = 0.08
    private static let targetFaceWidthRatio: CGFloat = 0.72
    private static let minimumFaceWidthRatio: CGFloat = 0.80
    private static let maximumFaceWidthToGuideRatio: CGFloat = 1.10
    private static let stableCenterDelta: CGFloat = 0.015
    private static let stableWidthDelta: CGFloat = 0.03

    private var smoothedFace: LiveFramingFaceGeometry?
    private var previousRawFace: LiveFramingFaceGeometry?
    private var committedState = LiveFramingGuidanceState.neutral
    private var pendingState: LiveFramingGuidanceState?
    private var pendingStateCount = 0

    mutating func evaluate(
        frame: LiveFramingFrame,
        previewSize: CGSize,
        mirrored: Bool
    ) -> LiveFramingGuidanceState {
        let candidate: LiveFramingGuidanceState

        if frame.faces.isEmpty {
            resetFaceTracking()
            candidate = .adjusting(.centerFace)
        } else if frame.faces.count > 1 {
            resetFaceTracking()
            candidate = .adjusting(.onePerson)
        } else if let face = LiveFramingGeometry.face(
            from: frame.faces[0],
            framePixelWidth: frame.pixelWidth,
            framePixelHeight: frame.pixelHeight,
            previewSize: previewSize,
            mirrored: mirrored
        ) {
            let stable = isStable(face, previewSize: previewSize)
            let smoothed = smooth(face)
            previousRawFace = face
            candidate = guidance(
                for: smoothed,
                stable: stable,
                previewSize: previewSize
            )
        } else {
            resetFaceTracking()
            candidate = .neutral
        }

        return debounce(candidate)
    }

    mutating func reset() -> LiveFramingGuidanceState {
        smoothedFace = nil
        previousRawFace = nil
        committedState = .neutral
        pendingState = nil
        pendingStateCount = 0
        return .neutral
    }

    private mutating func resetFaceTracking() {
        smoothedFace = nil
        previousRawFace = nil
    }

    private func isStable(
        _ face: LiveFramingFaceGeometry,
        previewSize: CGSize
    ) -> Bool {
        guard let previousRawFace else {
            return false
        }

        let centerDelta = hypot(
            face.boundingBox.midX - previousRawFace.boundingBox.midX,
            face.boundingBox.midY - previousRawFace.boundingBox.midY
        ) / max(previewSize.width, previewSize.height)
        let widthDelta = abs(
            face.boundingBox.width - previousRawFace.boundingBox.width
        ) / max(previousRawFace.boundingBox.width, 1)

        return centerDelta <= Self.stableCenterDelta
            && widthDelta <= Self.stableWidthDelta
    }

    private mutating func smooth(
        _ face: LiveFramingFaceGeometry
    ) -> LiveFramingFaceGeometry {
        guard let previous = smoothedFace else {
            smoothedFace = face
            return face
        }

        let factor = Self.smoothingFactor
        let smoothed = LiveFramingFaceGeometry(
            boundingBox: CGRect(
                x: interpolate(previous.boundingBox.minX, face.boundingBox.minX, factor),
                y: interpolate(previous.boundingBox.minY, face.boundingBox.minY, factor),
                width: interpolate(previous.boundingBox.width, face.boundingBox.width, factor),
                height: interpolate(previous.boundingBox.height, face.boundingBox.height, factor)
            ),
            eyeLineY: interpolate(previous.eyeLineY, face.eyeLineY, factor)
        )
        smoothedFace = smoothed
        return smoothed
    }

    private func interpolate(
        _ previous: CGFloat,
        _ current: CGFloat,
        _ factor: CGFloat
    ) -> CGFloat {
        previous + (current - previous) * factor
    }

    private func guidance(
        for face: LiveFramingFaceGeometry,
        stable: Bool,
        previewSize: CGSize
    ) -> LiveFramingGuidanceState {
        let guideRect = FaceGuideGeometry.rect(in: previewSize)
        let targetWidth = guideRect.width * Self.targetFaceWidthRatio
        let minimumWidth = targetWidth * Self.minimumFaceWidthRatio
        let maximumWidth = guideRect.width * Self.maximumFaceWidthToGuideRatio

        if face.boundingBox.width < minimumWidth {
            return .adjusting(.moveCloser)
        }
        if face.boundingBox.width > maximumWidth {
            return .adjusting(.moveBack)
        }
        if abs(face.boundingBox.midX - guideRect.midX)
            > previewSize.width * Self.centerTolerance {
            return .adjusting(.moveTowardCenter)
        }

        let targetEyeLine = FaceGuideGeometry.eyeLineY(in: previewSize)
        let eyeTolerance = previewSize.height * Self.eyeLineTolerance
        if face.eyeLineY > targetEyeLine + eyeTolerance {
            return .adjusting(.moveHigher)
        }
        if face.eyeLineY < targetEyeLine - eyeTolerance {
            return .adjusting(.moveLower)
        }
        if !stable {
            return .adjusting(.holdStill)
        }
        return .ready
    }

    private mutating func debounce(
        _ candidate: LiveFramingGuidanceState
    ) -> LiveFramingGuidanceState {
        if pendingState == candidate {
            pendingStateCount += 1
        } else {
            pendingState = candidate
            pendingStateCount = 1
        }

        let requiredCount = candidate == .ready
            ? Self.readySampleCount
            : Self.adjustmentSampleCount
        guard pendingStateCount >= requiredCount else {
            // Hard face-detection failures invalidate capture immediately. Soft
            // framing changes keep the last committed state until they persist.
            switch candidate {
            case .adjusting(.centerFace), .adjusting(.onePerson), .neutral:
                return .neutral
            case .ready, .adjusting:
                return committedState
            }
        }

        committedState = candidate
        return candidate
    }
}
