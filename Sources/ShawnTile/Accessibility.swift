import AppKit
import ApplicationServices

func axRead(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value
}
func axBool(_ element: AXUIElement, _ attribute: String) -> Bool { (axRead(element,attribute) as? Bool) == true }
func axFrame(_ element: AXUIElement) -> CGRect? {
    guard let p = axRead(element,kAXPositionAttribute), let s = axRead(element,kAXSizeAttribute),
          CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero, size = CGSize.zero
    guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
    return CGRect(origin:point,size:size)
}
@discardableResult func axSetFrame(_ element: AXUIElement, _ rect: CGRect) -> Bool {
    var point = rect.origin, size = rect.size
    guard let p = AXValueCreate(.cgPoint,&point), let s = AXValueCreate(.cgSize,&size) else { return false }
    // Position again after resizing: some apps clamp position using the previous size.
    _ = AXUIElementSetAttributeValue(element,kAXPositionAttribute as CFString,p)
    let resized = AXUIElementSetAttributeValue(element,kAXSizeAttribute as CFString,s)
    let moved = AXUIElementSetAttributeValue(element,kAXPositionAttribute as CFString,p)
    return resized == .success && moved == .success
}
struct ManagedWindow {
    let id: String
    let element: AXUIElement
    let app: NSRunningApplication
    var frame: CGRect
    var display: String
}
struct DisplayInfo: Identifiable {
    let id: String
    let name: String
    let area: CGRect
}
func connectedDisplays() -> [DisplayInfo] {
    let top = NSScreen.screens.first?.frame.maxY ?? 0
    return NSScreen.screens.enumerated().compactMap { index,screen in
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return nil }
        let uuid = CGDisplayCreateUUIDFromDisplayID(number).takeRetainedValue()
        let key = CFUUIDCreateString(nil,uuid) as String
        return DisplayInfo(id:key,name:screen.localizedName.isEmpty ? "Display \(index+1)" : screen.localizedName,area:TileCoreGeometry(screen.visibleFrame,top))
    }
}
// Keep conversion explicit at the AppKit/AX boundary.
private func TileCoreGeometry(_ r: CGRect,_ height: CGFloat) -> CGRect { CGRect(x:r.minX,y:height-r.maxY,width:r.width,height:r.height) }
