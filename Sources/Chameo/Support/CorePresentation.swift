extension DailyCaptureStatus {
    var accessibilityDescription: String {
        switch self {
        case .captured:
            return L10n.string("Captured")
        case .pendingToday:
            return L10n.string("Not captured yet")
        case .missed:
            return L10n.string("Missed")
        case .future:
            return L10n.string("Future")
        case .outsideTracking:
            return L10n.string("Before tracking began")
        case .unknown:
            return L10n.string("Status unavailable")
        }
    }
}

extension ReminderRepeat {
    var title: String {
        switch self {
        case .none:
            return L10n.string("Once")
        case .daily:
            return L10n.string("Daily")
        case .weekly:
            return L10n.string("Weekly")
        }
    }
}

extension LiveFramingHint {
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

extension LiveFramingGuidanceState {
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

extension CaptureQualitySuggestion {
    var message: String {
        switch self {
        case .faceNotDetected:
            return L10n.string("No face was detected. Place your face inside the guide and retake.")
        case .retakeRecommended:
            return L10n.string("This photo may not match the quality of your recent Chameos.")
        }
    }
}

extension AppLanguage {
    var pickerTitle: String {
        switch self {
        case .automatic:
            return L10n.string("language.automatic")
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        case .traditionalChinese:
            return "繁體中文"
        }
    }
}
