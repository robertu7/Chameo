import SwiftUI

struct TabPicker: View {
    @Binding var selection: ChameoTab

    var body: some View {
        ChameoSegmentedControl(options: ChameoTab.allCases, selection: $selection,
            title: { $0.title }, systemImage: { $0.systemImage },
            accessibilityTitle: L10n.string("View"))
    }
}
