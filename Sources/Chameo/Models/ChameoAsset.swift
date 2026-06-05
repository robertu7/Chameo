import Foundation
import Photos

struct ChameoAsset: Identifiable, Equatable {
    let id: String
    let asset: PHAsset

    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.asset = asset
    }

    var createdAt: Date? {
        asset.creationDate
    }
}
