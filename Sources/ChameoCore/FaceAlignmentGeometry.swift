import CoreGraphics

public enum FaceAlignmentGeometry {
    public struct Input: Sendable {
        public let imageSize: CGSize
        public let leftEye: CGPoint
        public let rightEye: CGPoint
        public let nose: CGPoint
        public let mouth: CGPoint

        public init(
            imageSize: CGSize,
            leftEye: CGPoint,
            rightEye: CGPoint,
            nose: CGPoint,
            mouth: CGPoint
        ) {
            self.imageSize = imageSize
            self.leftEye = leftEye
            self.rightEye = rightEye
            self.nose = nose
            self.mouth = mouth
        }
    }

    public struct Plan: Sendable {
        public let outputSize: CGSize
        public let transform: CGAffineTransform
        public let rotationRadians: CGFloat
        public let scale: CGFloat
        public let anchor: CGPoint
        public let targetAnchor: CGPoint
    }

    public static let outputLength: CGFloat = 1200
    public static let targetEyeDistanceRatio: CGFloat = 0.20
    public static let targetAnchor = CGPoint(
        x: outputLength * 0.5,
        y: outputLength * 0.48
    )

    public static func plan(for input: Input) throws -> Plan {
        guard input.imageSize.width > 0, input.imageSize.height > 0 else {
            throw FaceAlignmentGeometryError.invalidImageSize
        }
        let eyeVector = CGPoint(
            x: input.rightEye.x - input.leftEye.x,
            y: input.rightEye.y - input.leftEye.y
        )
        let eyeDistance = hypot(eyeVector.x, eyeVector.y)
        guard eyeDistance > 0 else {
            throw FaceAlignmentGeometryError.invalidLandmarks
        }
        let rotation = -atan2(eyeVector.y, eyeVector.x)
        let scale = (outputLength * targetEyeDistanceRatio) / eyeDistance
        let anchor = CGPoint(
            x: (input.leftEye.x + input.rightEye.x + input.nose.x + input.mouth.x) / 4,
            y: (input.leftEye.y + input.rightEye.y + input.nose.y + input.mouth.y) / 4
        )
        let transform = CGAffineTransform.identity
            .translatedBy(x: targetAnchor.x, y: targetAnchor.y)
            .scaledBy(x: scale, y: scale)
            .rotated(by: rotation)
            .translatedBy(x: -anchor.x, y: -anchor.y)
        return Plan(
            outputSize: CGSize(width: outputLength, height: outputLength),
            transform: transform,
            rotationRadians: rotation,
            scale: scale,
            anchor: anchor,
            targetAnchor: targetAnchor
        )
    }
}

public enum FaceAlignmentGeometryError: Error, Sendable {
    case invalidImageSize
    case invalidLandmarks
}
