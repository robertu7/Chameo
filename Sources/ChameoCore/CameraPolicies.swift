import CoreGraphics

public struct CameraSelectionCandidate: Equatable, Sendable {
    public let uniqueID: String
    public let isBuiltIn: Bool

    public init(uniqueID: String, isBuiltIn: Bool) {
        self.uniqueID = uniqueID
        self.isBuiltIn = isBuiltIn
    }
}

public enum CameraSelectionPolicy {
    public static func preferredUniqueID(
        systemPreferredUniqueID: String?,
        userPreferredUniqueID: String?,
        candidates: [CameraSelectionCandidate]
    ) -> String? {
        if let systemPreferredUniqueID,
           candidates.contains(where: { $0.uniqueID == systemPreferredUniqueID }) {
            return systemPreferredUniqueID
        }
        if let userPreferredUniqueID,
           candidates.contains(where: { $0.uniqueID == userPreferredUniqueID }) {
            return userPreferredUniqueID
        }
        return candidates.first(where: \.isBuiltIn)?.uniqueID ?? candidates.first?.uniqueID
    }
}

public enum CameraMirroringPolicy {
    public static func shouldMirrorPreview(isContinuityCamera: Bool) -> Bool {
        !isContinuityCamera
    }

    public static let mobileFrontPreviewIsMirrored = true
    public static let mobileSavedImageIsMirrored = false
}

public enum MobileInterfaceOrientation: Equatable, Sendable {
    case portrait
    case portraitUpsideDown
    case landscapeLeft
    case landscapeRight
}

public enum MobileCameraOrientationPolicy {
    public static func clockwiseRotationAngle(
        for orientation: MobileInterfaceOrientation
    ) -> CGFloat {
        switch orientation {
        case .portrait: 90
        case .portraitUpsideDown: 270
        case .landscapeLeft: 0
        case .landscapeRight: 180
        }
    }
}
