import SwiftUI

struct SettingsToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            SettingsLabel(title: title, description: description)
        }
        .accessibilityLabel(title)
        .accessibilityHint(description)
    }
}

