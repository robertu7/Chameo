import SwiftUI

struct TabPicker: View {
    @Binding var selection: ChameoTab

    var body: some View {
        Picker(L10n.string("View"), selection: $selection) {
            ForEach(ChameoTab.allCases) { tab in
                Label(tab.title, systemImage: tab.systemImage).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel(L10n.string("View"))
    }
}
