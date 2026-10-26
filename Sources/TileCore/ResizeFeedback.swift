import Foundation
import CoreGraphics

/// A successful AX call is an acknowledgement, not proof that resizing has settled.
public enum ResizeFeedback {
    public static func minimum(prior: CGSize, target: CGSize, first: CGSize?, confirmed: CGSize?, written: Bool, before: CGSize? = nil, probe: CGSize? = nil) -> CGSize {
        guard written, let first, let actual = confirmed,
              first.width.isFinite, first.height.isFinite,
              actual.width.isFinite, actual.height.isFinite,
              first.width > 0, first.height > 0, actual.width > 0, actual.height > 0,
              abs(first.width - actual.width) <= 4, abs(first.height - actual.height) <= 4 else { return prior }
        // An accepted smaller size disproves a previous minimum. Otherwise a
        // transient observation can keep every later layout collapsed forever.
        func dimension(_ prior: CGFloat, _ requested: CGFloat, _ observed: CGFloat, _ previous: CGFloat?, _ probe: CGFloat?) -> CGFloat {
            // A successful write that leaves an axis unchanged does not prove
            // that its current dimension is a minimum: the client may ignore it.
            // A smaller pre-request frame also disproves a stale learned bound.
            let known = previous.map { min(prior, $0) } ?? prior
            guard observed > requested + 4 else { return min(known, observed) }
            if let previous, abs(observed - previous) <= 4 {
                let responded = probe.map { $0.isFinite && $0 > 0 && abs($0-previous) > 4 } ?? false
                if !responded { return known }
            }
            return observed
        }
        return CGSize(width: dimension(prior.width,target.width,actual.width,before?.width,probe?.width),
                      height: dimension(prior.height,target.height,actual.height,before?.height,probe?.height))
    }

    public static func matches(_ actual: CGRect, _ target: CGRect) -> Bool {
        abs(actual.minX - target.minX) <= 4 && abs(actual.minY - target.minY) <= 4 &&
        abs(actual.width - target.width) <= 4 && abs(actual.height - target.height) <= 4
    }
}
