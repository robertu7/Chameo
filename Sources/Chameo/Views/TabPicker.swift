import AppKit
import SwiftUI

struct TabPicker: NSViewRepresentable {
    @Binding var selection: ChameoTab

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let tabs = ChameoTab.allCases
        let control = NSSegmentedControl(
            labels: tabs.map(\.title),
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.selectionChanged(_:))
        )

        control.segmentDistribution = .fit
        control.setAccessibilityLabel(L10n.string("View"))

        for (index, tab) in tabs.enumerated() {
            let image = NSImage(
                systemSymbolName: tab.systemImage,
                accessibilityDescription: tab.title
            )
            image?.isTemplate = true
            control.setImage(image, forSegment: index)
            control.setImageScaling(.scaleProportionallyDown, forSegment: index)
            control.setWidth(104, forSegment: index)
            control.setToolTip(tab.title, forSegment: index)
        }

        updateSelection(in: control)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        control.setAccessibilityLabel(L10n.string("View"))
        for (index, tab) in ChameoTab.allCases.enumerated() {
            control.setLabel(tab.title, forSegment: index)
            control.setToolTip(tab.title, forSegment: index)
        }
        updateSelection(in: control)
    }

    private func updateSelection(in control: NSSegmentedControl) {
        guard let index = ChameoTab.allCases.firstIndex(of: selection),
              control.selectedSegment != index
        else {
            return
        }

        control.selectedSegment = index
    }

    final class Coordinator: NSObject {
        @Binding private var selection: ChameoTab

        init(selection: Binding<ChameoTab>) {
            _selection = selection
        }

        @objc func selectionChanged(_ sender: NSSegmentedControl) {
            guard ChameoTab.allCases.indices.contains(sender.selectedSegment) else {
                return
            }

            selection = ChameoTab.allCases[sender.selectedSegment]
        }
    }
}
