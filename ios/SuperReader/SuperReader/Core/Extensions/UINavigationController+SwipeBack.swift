import UIKit

// MARK: - Swipe-to-go-back with a hidden navigation bar
//
// HIG · Designing for iOS: "let people swipe to navigate back". The reader,
// Up next and per-feed screens draw their own top chrome and hide the system
// navigation bar (`.toolbar(.hidden, for: .navigationBar)`), which makes
// UIKit drop the interactive pop gesture. Re-own the gesture's delegate so
// the edge swipe keeps working whenever there is something to pop to.

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == interactivePopGestureRecognizer else { return true }
        return viewControllers.count > 1
    }
}
