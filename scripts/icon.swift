import AppKit
let directory = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
for size in [16,32,128,256,512] { for scale in [1,2] {
    let pixels = size*scale
    let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels,pixelsHigh:pixels,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
    let s = CGFloat(pixels)
    NSColor(calibratedRed:0.055,green:0.08,blue:0.14,alpha:1).setFill()
    NSBezierPath(roundedRect:NSRect(x:0,y:0,width:s,height:s),xRadius:s*0.22,yRadius:s*0.22).fill()
    let gap = s*0.045, margin = s*0.19, width = (s-margin*2-gap)/2
    let rects = [NSRect(x:margin,y:margin,width:width,height:s-margin*2),NSRect(x:margin+width+gap,y:s/2+gap/2,width:width,height:(s-margin*2-gap)/2),NSRect(x:margin+width+gap,y:margin,width:width,height:(s-margin*2-gap)/2)]
    for (i,r) in rects.enumerated() {
        NSColor(calibratedRed:0.16,green:i == 0 ? 0.8 : 0.45,blue:0.94,alpha:1).setFill()
        NSBezierPath(roundedRect:r,xRadius:s*0.035,yRadius:s*0.035).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    let file = "\(directory)/icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
    try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:file))
} }
