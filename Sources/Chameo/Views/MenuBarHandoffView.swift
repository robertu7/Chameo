import AppKit
import SwiftUI

struct MenuBarHandoffView: View {
    let onOpenChameo: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: StatusMenuIcon.image(
                named: "eye",
                appearance: NSApp.effectiveAppearance
            ))
            .resizable()
            .scaledToFit()
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text(L10n.string("Chameo is ready"))
                    .font(.title2.bold())

                Text(L10n.string("Chameo lives in your menu bar."))
                    .font(.body)

                Text(L10n.string("Can’t see the eye? Hold Command and drag it closer to the right. You can always reopen Chameo from Spotlight or Applications."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(L10n.string("Open Chameo"), action: onOpenChameo)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(width: 420, height: 300)
    }
}
