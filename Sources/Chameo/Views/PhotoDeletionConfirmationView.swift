import SwiftUI

struct PhotoDeletionConfirmationView: View {
    @Binding var trashLocalCopy: Bool
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.string("Deletes from Photos and, if iCloud Photos is on, all synced devices. Keeps the local copy unless selected below."))
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(L10n.string("Also Move the Local Copy to Trash"), isOn: $trashLocalCopy)
                .toggleStyle(.checkbox)
                .font(.caption)

            HStack {
                Spacer()
                Button(L10n.string("Cancel"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(L10n.string("Delete from Photos"), role: .destructive, action: onDelete)
            }
            .controlSize(.small)
        }
    }
}
