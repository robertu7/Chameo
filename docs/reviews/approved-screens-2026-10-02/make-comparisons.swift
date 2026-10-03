import AppKit
let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let entries: [(String,String,CGRect,String)] = [
 ("general","draft-settings.png",CGRect(x:43,y:86,width:552,height:534),"english-light-settings-general.png"),
 ("capture","draft-settings.png",CGRect(x:625,y:86,width:552,height:534),"english-light-settings-capture.png"),
 ("reminders","draft-settings.png",CGRect(x:43,y:725,width:552,height:534),"english-light-settings-reminders.png"),
 ("photos","draft-settings.png",CGRect(x:625,y:725,width:552,height:534),"english-light-settings-photos.png"),
 ("camera-review","draft-main.png",CGRect(x:601,y:61,width:514,height:580),"english-light-camera-review.png"),
 ("library-captured","draft-main.png",CGRect(x:44,y:720,width:515,height:600),"english-light-library-captured.png"),
 ("library-today","draft-main.png",CGRect(x:600,y:720,width:515,height:600),"english-light-library-today.png"),
 ("onboarding-capture","draft-onboarding.png",CGRect(x:35,y:115,width:586,height:671),"english-light-onboarding-0.png"),
 ("onboarding-story","draft-onboarding.png",CGRect(x:649,y:115,width:587,height:671),"english-light-onboarding-1.png"),
 ("onboarding-permissions","draft-onboarding.png",CGRect(x:1268,y:115,width:586,height:671),"english-light-onboarding-2.png")
]
for (name, source, crop, screenshot) in entries {
 let raw = NSImage(contentsOf:dir.appendingPathComponent(source))!
 let cg = raw.cgImage(forProposedRect:nil,context:nil,hints:nil)!.cropping(to:crop)!
 let reference = NSImage(cgImage:cg,size:CGSize(width:cg.width,height:cg.height))
 let rendered = NSImage(contentsOf:dir.appendingPathComponent(screenshot))!
 let canvas = NSImage(size:CGSize(width:2040,height:1180))
 canvas.lockFocus()
 NSColor.white.setFill(); NSRect(x:0,y:0,width:2040,height:1180).fill()
 for (i,img) in [reference,rendered].enumerated() {
  let ratio = min(1000/img.size.width,1120/img.size.height)
  let size = CGSize(width:img.size.width*ratio,height:img.size.height*ratio)
  img.draw(in:CGRect(x:CGFloat(i)*1020+10+(1000-size.width)/2,y:10+(1120-size.height)/2,width:size.width,height:size.height))
  let label = i==0 ? "Approved draft" : "Native content render · glass / tabs require on-screen review"
  (label as NSString).draw(at:CGPoint(x:CGFloat(i)*1020+12,y:1144),withAttributes:[.font:NSFont.systemFont(ofSize:18,weight:.semibold),.foregroundColor:NSColor.black])
 }
 canvas.unlockFocus()
 let rep = NSBitmapImageRep(data:canvas.tiffRepresentation!)!
 try rep.representation(using:.png,properties:[:])!.write(to:dir.appendingPathComponent("comparison-"+name+".png"))
}
