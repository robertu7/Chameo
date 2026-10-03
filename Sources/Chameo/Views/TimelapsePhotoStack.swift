import SwiftUI

/// Static album thumbnails stay in place throughout creation and completion.
struct TimelapsePhotoStack: View {
    let assets: [ChameoAsset]
    let side: CGFloat
    var loader: (ChameoAsset) async -> NSImage?

    var body: some View {
        ZStack {
            if assets.isEmpty {
                Image(systemName: "photo.stack").font(.system(size: 56)).foregroundStyle(.tertiary)
            } else {
                if assets.count > 1 {
                    photo(assets[0], size: side * 0.9).rotationEffect(.degrees(-10)).offset(x: -side * 0.64, y: 10)
                }
                if assets.count > 2 {
                    photo(assets[assets.count - 1], size: side * 0.9).rotationEffect(.degrees(10)).offset(x: side * 0.64, y: 10)
                }
                photo(assets[assets.count / 2], size: side)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: side + 10)
        .accessibilityHidden(true)
    }

    private func photo(_ asset: ChameoAsset, size: CGFloat) -> some View {
        TimelapsePhotoPreview(asset: asset, loader: loader)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .chameoImageOutline(cornerRadius: 6)
            .shadow(color: .black.opacity(0.14), radius: 6, y: 3)
    }
}

private struct TimelapsePhotoPreview: View {
    let asset: ChameoAsset
    let loader: (ChameoAsset) async -> NSImage?
    @State private var image: NSImage?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.secondary.opacity(0.08)
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else {
                    Image(systemName: "photo").font(.largeTitle).foregroundStyle(.tertiary)
                }
            }
        }
        .task(id: asset.id) {
            image = nil
            let loaded = await loader(asset)
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }
}
