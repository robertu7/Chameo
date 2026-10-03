import AppKit
let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let source = NSImage(contentsOf: dir.appendingPathComponent("reported-settings.png"))!
let cropped = source.cgImage(forProposedRect: nil, context: nil, hints: nil)!.cropping(to: CGRect(x: 112, y: 140, width: 1000, height: 920))!
let before = NSImage(cgImage: cropped, size: CGSize(width: 1000, height: 920))
let after = NSImage(contentsOf: dir.appendingPathComponent("english-light-settings-photos.png"))!
let canvas = NSImage(size: CGSize(width: 2040, height: 980))
canvas.lockFocus()
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 2040, height: 980).fill()
for (index, img) in [before, after].enumerated() {
    img.draw(in: CGRect(x: index * 1020 + 10, y: 10, width: 1000, height: 920))
    let label = index == 0 ? "Reported Settings content" : "Fixed content render · native glass requires live review"
    (label as NSString).draw(at: CGPoint(x: index * 1020 + 12, y: 946), withAttributes: [.font: NSFont.systemFont(ofSize: 18, weight: .semibold), .foregroundColor: NSColor.black])
}
canvas.unlockFocus()
let bitmap = NSBitmapImageRep(data: canvas.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent("comparison-settings.png"))
