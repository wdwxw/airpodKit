import AppKit
import SwiftUI

/// Frosted-glass backdrop for the popover — wraps `NSVisualEffectView` so the
/// SwiftUI content can sit on top of a real system blur/vibrancy material
/// instead of a flat color.
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    // `.behindWindow` samples whatever is behind the *window*, which is
    // unreliable inside an NSPopover: the popover's own auto-generated
    // backing window/chrome sits between this view and the desktop, so
    // `.behindWindow` can render as a flat/opaque fill instead of a blur
    // depending on timing and appearance. `.withinWindow` blends against
    // the popover's own content instead, which is the documented-safe
    // choice for views embedded in an existing window rather than a
    // borderless panel.
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
