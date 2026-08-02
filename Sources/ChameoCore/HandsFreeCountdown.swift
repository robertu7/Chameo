public enum HandsFreeCountdownPhase: Equatable, Sendable {
    case inactive
    case armed
    case counting(Int)
    case locked

    public var displayedCount: Int? {
        guard case .counting(let count) = self else {
            return nil
        }
        return count
    }
}

public enum HandsFreeCountdownEvent: Equatable, Sendable {
    case setEnabled(Bool)
    case setVisible(Bool)
    case guidanceChanged(LiveFramingGuidanceState)
    case tick
    case manualCapture
}

public enum HandsFreeCountdownEffect: Equatable, Sendable {
    case startTimer
    case cancelTimer
    case capture
}

public struct HandsFreeCountdownMachine: Sendable {
    private static let correctiveSampleLimit = 3

    public private(set) var phase = HandsFreeCountdownPhase.inactive

    private var isEnabled = false
    private var isVisible = false
    private var isLockedForReadyCycle = false
    private var latestGuidance = LiveFramingGuidanceState.neutral
    private var consecutiveCorrectiveSamples = 0

    public init() {}

    public mutating func handle(
        _ event: HandsFreeCountdownEvent
    ) -> [HandsFreeCountdownEffect] {
        switch event {
        case .setEnabled(let enabled):
            return setEnabled(enabled)

        case .setVisible(let visible):
            return setVisible(visible)

        case .guidanceChanged(let guidance):
            return guidanceChanged(guidance)

        case .tick:
            return tick()

        case .manualCapture:
            let shouldCancel = phase.displayedCount != nil
            isLockedForReadyCycle = true
            phase = isEnabled && isVisible ? .locked : .inactive
            return shouldCancel ? [.cancelTimer] : []
        }
    }

    private mutating func setEnabled(
        _ enabled: Bool
    ) -> [HandsFreeCountdownEffect] {
        guard isEnabled != enabled else {
            return []
        }

        let shouldCancel = phase.displayedCount != nil
        isEnabled = enabled
        isLockedForReadyCycle = false
        resetGuidanceTracking()
        phase = enabled && isVisible ? .armed : .inactive
        return shouldCancel ? [.cancelTimer] : []
    }

    private mutating func setVisible(
        _ visible: Bool
    ) -> [HandsFreeCountdownEffect] {
        guard isVisible != visible else {
            return []
        }

        let shouldCancel = phase.displayedCount != nil
        isVisible = visible
        resetGuidanceTracking()
        if isEnabled && visible {
            phase = isLockedForReadyCycle ? .locked : .armed
        } else {
            phase = .inactive
        }
        return shouldCancel ? [.cancelTimer] : []
    }

    private mutating func guidanceChanged(
        _ guidance: LiveFramingGuidanceState
    ) -> [HandsFreeCountdownEffect] {
        guard isEnabled, isVisible else {
            return []
        }

        latestGuidance = guidance

        switch guidance {
        case .ready:
            consecutiveCorrectiveSamples = 0
            guard !isLockedForReadyCycle,
                  phase.displayedCount == nil else {
                return []
            }
            phase = .counting(3)
            return [.startTimer]

        case .adjusting(let hint):
            if phase == .locked {
                consecutiveCorrectiveSamples = 0
                isLockedForReadyCycle = false
                phase = .armed
                return []
            }

            guard phase.displayedCount != nil else {
                consecutiveCorrectiveSamples = 0
                isLockedForReadyCycle = false
                phase = .armed
                return []
            }

            consecutiveCorrectiveSamples += 1
            let shouldCancelImmediately =
                hint == .centerFace || hint == .onePerson
            guard shouldCancelImmediately ||
                    consecutiveCorrectiveSamples >= Self.correctiveSampleLimit else {
                return []
            }

            let shouldCancel = phase.displayedCount != nil
            isLockedForReadyCycle = false
            consecutiveCorrectiveSamples = 0
            phase = .armed
            return shouldCancel ? [.cancelTimer] : []

        case .neutral:
            resetGuidanceTracking()
            guard phase.displayedCount != nil else {
                return []
            }
            phase = .armed
            return [.cancelTimer]
        }
    }

    private mutating func tick() -> [HandsFreeCountdownEffect] {
        switch phase {
        case .counting(3):
            phase = .counting(2)
        case .counting(2):
            phase = .counting(1)
        case .counting(1):
            guard latestGuidance == .ready else {
                consecutiveCorrectiveSamples = 0
                phase = .armed
                return [.cancelTimer]
            }
            isLockedForReadyCycle = true
            phase = .locked
            return [.capture]
        case .inactive, .armed, .locked, .counting:
            break
        }
        return []
    }

    private mutating func resetGuidanceTracking() {
        latestGuidance = .neutral
        consecutiveCorrectiveSamples = 0
    }
}
