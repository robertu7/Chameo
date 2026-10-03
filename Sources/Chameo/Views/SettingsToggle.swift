import SwiftUI

struct SettingsToggle: View {
    let title: String
    var description: String = ""
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            SettingsLabel(title: title, description: description)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityLabel(title)
        .accessibilityHint(description)
    }
}

