import AppKit
import SwiftUI

struct CapturedPreview: Identifiable {
    let id = UUID()
    let data: Data
    let image: NSImage?
    let qualityEvaluation: FaceCaptureQualityEvaluation
    let qualitySuggestion: CaptureQualitySuggestion?

    init(
        data: Data,
        qualityEvaluation: FaceCaptureQualityEvaluation,
        qualitySuggestion: CaptureQualitySuggestion?
    ) {
        self.data = data
        self.image = NSImage(data: data)
        self.qualityEvaluation = qualityEvaluation
        self.qualitySuggestion = qualitySuggestion
    }
}
struct CapturedPreviewView: View {
    let preview: CapturedPreview
    let isSaving: Bool
    let photosPermissionDenied: Bool
    let locationPermissionDenied: Bool
    let onRetake: () -> Void
    let onKeep: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottom) {
                if let image = preview.image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 392, height: imageHeight)
                        .background(.black)
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 392, height: imageHeight)
                }

                qualitySuggestionBanner
            }
            .frame(width: 392, height: imageHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .chameoImageOutline(cornerRadius: 8)

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) { actionButtons }
                    .controlSize(.large)
            }
            .frame(width: 392)

            if photosPermissionDenied {
                PermissionStatusInline(
                    message: L10n.string("Allow Photos access to save this Chameo."),
                    destination: .photos
                )
                .frame(width: 392)
            }

            if locationPermissionDenied {
                PermissionStatusInline(
                    message: L10n.string("Location access is off. This Chameo will be saved without location data."),
                    destination: .location
                )
                .frame(width: 392)
            }
        }
        .frame(
            width: ChameoLayout.contentWidth,
            height: ChameoLayout.contentHeight,
            alignment: .top
        )
    }

    private var imageHeight: CGFloat {
        var height = ChameoLayout.livePreviewHeight

        if photosPermissionDenied {
            height -= 28
        }
        if locationPermissionDenied {
            height -= 28
        }

        return height
    }

    @ViewBuilder
    private var qualitySuggestionBanner: some View {
        if let suggestion = preview.qualitySuggestion {
            Label(suggestion.message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .chameoReadableSurface(in: Rectangle())
                .accessibilityLabel(L10n.format("Retake suggested. %@", suggestion.message))
        }
    }

    private var keepButtonTitle: String {
        if isSaving {
            return L10n.string("Saving…")
        }
        return preview.qualitySuggestion == nil
            ? L10n.string("Save to Photos")
            : L10n.string("Save Anyway")
    }

    @ViewBuilder
    private var actionButtons: some View {
        if preview.qualitySuggestion != nil {
            Button(L10n.string("Retake"), action: onRetake)
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.cancelAction)
                .disabled(isSaving)

            Spacer()

            Button(keepButtonTitle, action: onKeep)
                .buttonStyle(.glass)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(isSaving)
        } else {
            Button(L10n.string("Retake"), action: onRetake)
                .frame(maxWidth: .infinity)
                .buttonStyle(.glass)
                .keyboardShortcut(.cancelAction)
                .disabled(isSaving)

            Spacer()

            Button(keepButtonTitle, action: onKeep)
                .frame(maxWidth: .infinity)
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving)
        }
    }
}
