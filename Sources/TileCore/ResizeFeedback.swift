import Foundation
import CoreGraphics

/// A successful AX call is an acknowledgement, not proof that resizing has settled.
public enum ResizeFeedback {
    public static func minimum(prior: CGSize, target: CGSize, first: CGSize?, confirmed: CGSize?, written: Bool) -> CGSize {
        guard written, let first, let actual = confirmed,
              first.width.isFinite, first.height.isFinite,
              actual.width.isFinite, actual.height.isFinite,
              first.width > 0, first.height > 0, actual.width > 0, actual.height > 0,
              abs(first.width - actual.width) <= 4, abs(first.height - actual.height) <= 4 else { return prior }
        // An accepted smaller size disproves a previous minimum. Otherwise a
        // transient observation can keep every later layout collapsed forever.
        return CGSize(width: actual.width > target.width + 4 ? actual.width : min(prior.width, actual.width),
                      height: actual.height > target.height + 4 ? actual.height : min(prior.height, actual.height))
    }

    public static func matches(_ actual: CGRect, _ target: CGRect) -> Bool {
        abs(actual.minX - target.minX) <= 4 && abs(actual.minY - target.minY) <= 4 &&
        abs(actual.width - target.width) <= 4 && abs(actual.height - target.height) <= 4
    }
}
