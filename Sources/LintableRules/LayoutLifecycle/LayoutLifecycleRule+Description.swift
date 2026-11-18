import LintableKit

public extension LayoutLifecycleRule {
    static let description = RuleDescription(
        id: "layout_lifecycle",
        name: "Layout lifecycle",
        summary: """
        Views get geometry only during layout: set `frame`, `bounds`, `center` or a layer's `position` in \
        `layoutSubviews()` and its relatives, not in gesture handlers, callbacks or setters.
        """,
        rationale: """
        When one function turns state and bounds into geometry, every reason to lay out again goes through the \
        same code: rotation, a size class change, window resizing, Dynamic Type, the first layout. A gesture can't \
        leave a frame computed from bounds that have since changed, and animating becomes "change the state, then \
        animate `layoutIfNeeded()`". It's how UIKit and AppKit are designed to be used: override `layoutSubviews()` \
        (or `layout()`), invalidate with `setNeedsLayout()`.

        The rule looks at one file at a time, matches functions by name and labels, and has no type information, \
        so its answers are fast and predictable. A property named `frame` on a model type looks like a view's; \
        suppress it with a directive and a reason, or rename the property.
        """,
        category: .layout,
        defaultSeverity: .warning,
        optionDescriptions: [
            "properties": "Properties whose assignment is a layout write, with their `origin`, `size`, `x`, `y`, `width` and `height` parts.",
            "check_transform": "Also treat `transform` as a layout write. Off by default: a rotation or a press-down scale doesn't depend on the view's size.",
            "layout_methods": "Methods, by name and labels, where layout writes are allowed.",
            "exempt_transitions": """
            Allow layout writes in UIKit transition methods, which hand you start and end frames to animate. A `private` \
            or `fileprivate` function that only transition methods in its file call, directly or through other such \
            functions, is part of the transition.
            """,
            "transition_methods": "The transition methods that `exempt_transitions` allows.",
            "exempt_superclasses": "Classes whose subclasses compute layout attributes rather than move views, so anything inside them is allowed.",
            "helper_prefix": """
            A `private` or `fileprivate` function named with this prefix and an uppercase letter is a layout helper, \
            allowed when every call to it in its file comes from a layout method, a transition or another allowed helper.
            """,
            "deferred_calls": """
            Calls whose closures run later, outside the layout pass, even when passed from a layout method. \
            `A.b` matches `A.b` and `A.x.b`; `b` matches any call ending in `b`.
            """,
        ],
        triggeringExamples: [
            Example("""
            final class ChartView: UIView {
                @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
                    1️⃣highlightLine.center.x = recognizer.location(in: self).x
                }
            }
            """),
            Example("""
            final class BadgeView: UIView {
                override func layoutSubviews() {
                    super.layoutSubviews()
                    DispatchQueue.main.async {
                        1️⃣self.badge.frame = self.bounds
                    }
                }
            }
            """),
            Example("""
            final class ToolbarView: UIView {
                func select(_ indexPath: IndexPath) {
                    selectedIndexPath = indexPath
                    1️⃣layoutIndicator()
                }

                override func layoutSubviews() {
                    super.layoutSubviews()
                    layoutIndicator()
                }

                private func layoutIndicator() {
                    indicator.frame = indicatorFrame
                }
            }
            """),
            Example("""
            final class CardView: UIView {
                var isExpanded = false {
                    didSet {
                        1️⃣frame.size.height = isExpanded ? 320 : 120
                    }
                }
            }
            """),
            Example("""
            final class ProgressView: UIView {
                override init(frame: CGRect) {
                    super.init(frame: frame)
                    1️⃣indicatorLayer.position = CGPoint(x: 0, y: frame.midY)
                }
            }
            """),
            Example("""
            final class LegendView: UIView {
                override func layoutSubviews() {
                    super.layoutSubviews()
                    layoutLegend()
                }

                func 1️⃣layoutLegend() {
                    legend.frame = bounds
                }
            }
            """),
            Example("""
            final class OverlayView: UIView {
                func setUp() {
                    button.addTarget(self, action: 1️⃣#selector(layoutOverlay), for: .touchUpInside)
                }

                @objc private func 2️⃣layoutOverlay() {
                    overlay.frame = bounds
                }
            }
            """),
            Example("""
            final class CardPresentationController: UIPresentationController {
                override func presentationTransitionWillBegin() {
                    moveCard(to: frameOfPresentedViewInContainerView)
                }

                @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
                    let offset = recognizer.translation(in: containerView).y
                    moveCard(to: frameOfPresentedViewInContainerView.offsetBy(dx: 0, dy: offset))
                }

                private func moveCard(to frame: CGRect) {
                    1️⃣presentedView?.frame = frame
                }
            }
            """),
            Example("""
            final class SpinnerView: UIView {
                func spin() {
                    1️⃣icon.transform = CGAffineTransform(rotationAngle: .pi)
                }
            }
            """, options: "check_transform: true"),
        ],
        nonTriggeringExamples: [
            Example("""
            final class ChartView: UIView {
                private var highlightedX: CGFloat? {
                    didSet { setNeedsLayout() }
                }

                @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
                    highlightedX = recognizer.location(in: self).x
                }

                override func layoutSubviews() {
                    super.layoutSubviews()
                    UIView.performWithoutAnimation {
                        layoutHighlight()
                    }
                }

                private func layoutHighlight() {
                    highlightLine.isHidden = highlightedX == nil
                    highlightLine.frame = CGRect(x: (highlightedX ?? 0) - 1, y: 0, width: 2, height: bounds.height)
                }
            }
            """),
            Example("""
            final class CardTransition: NSObject, UIViewControllerAnimatedTransitioning {
                func animateTransition(using context: UIViewControllerContextTransitioning) {
                    guard let controller = context.viewController(forKey: .to) else { return }
                    controller.view.frame = context.initialFrame(for: controller)
                    UIView.animate(withDuration: 0.3) {
                        controller.view.frame = context.finalFrame(for: controller)
                    }
                }
            }
            """),
            Example("""
            final class SlideTransition: NSObject, UIViewControllerAnimatedTransitioning {
                func animateTransition(using context: UIViewControllerContextTransitioning) {
                    guard let controller = context.viewController(forKey: .to) else { return }
                    slide(controller.view, to: context.finalFrame(for: controller), in: context)
                }

                private func slide(_ view: UIView, to finalFrame: CGRect, in context: UIViewControllerContextTransitioning) {
                    view.frame = finalFrame.offsetBy(dx: finalFrame.width, dy: 0)
                    UIView.animate(withDuration: 0.3, animations: {
                        view.frame = finalFrame
                    }, completion: { _ in
                        context.completeTransition(!context.transitionWasCancelled)
                    })
                }
            }
            """),
            Example("""
            class BaseLayout: UICollectionViewLayout {}

            final class GridLayout: BaseLayout {
                private func makeAttributes(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes {
                    let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                    attributes.frame = frame(at: indexPath)
                    return attributes
                }
            }
            """),
            Example("""
            final class SheetPresentationController: UIPresentationController {
                override func containerViewWillLayoutSubviews() {
                    super.containerViewWillLayoutSubviews()
                    presentedView?.frame = frameOfPresentedViewInContainerView
                }

                override var frameOfPresentedViewInContainerView: CGRect {
                    var frame = containerView?.bounds ?? .zero
                    frame.origin.y += 48
                    return frame
                }
            }
            """),
            Example("""
            struct Placement {
                var frame: CGRect

                mutating func move(by offset: CGFloat) {
                    frame.origin.x += offset
                }
            }
            """),
            Example("""
            final class ChevronView: UIView {
                func setCollapsed(_ collapsed: Bool) {
                    UIView.animate(withDuration: 0.2) {
                        self.chevron.transform = collapsed ? CGAffineTransform(rotationAngle: .pi) : .identity
                    }
                }
            }
            """),
            Example("""
            final class CanvasView: NSView {
                override func layout() {
                    super.layout()
                    canvas.frame = bounds
                }
            }
            """),
        ],
        howToFix: """
        Keep the state that decides geometry on the view, call `setNeedsLayout()` when it changes, and set every \
        frame in `layoutSubviews()` (or a private `layout…` helper it calls).

        **Gesture-driven position.** The handler stores what's highlighted; layout positions the views.

        ```swift
        private var highlightedX: CGFloat? {
            didSet { setNeedsLayout() }
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            highlightedX = recognizer.state == .ended ? nil : recognizer.location(in: self).x
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            layoutHighlight()
        }
        ```

        **Animated move.** Change the state, then animate the layout pass. Use `UIView.performWithoutAnimation` for \
        the first placement.

        ```swift
        func select(_ indexPath: IndexPath, animated: Bool) {
            selectedIndexPath = indexPath
            setNeedsLayout()
            guard animated else { return }
            UIView.animate(withDuration: 0.3) {
                self.layoutIfNeeded()
            }
        }
        ```

        **Keyboard in a presentation controller.** Keep the keyboard height, invalidate the container, and set the \
        presented view's frame in `containerViewWillLayoutSubviews()`.

        ```swift
        private var keyboardHeight: CGFloat = 0 {
            didSet { containerView?.setNeedsLayout() }
        }

        override func containerViewWillLayoutSubviews() {
            super.containerViewWillLayoutSubviews()
            presentedView?.frame = frameOfPresentedViewInContainerView
        }
        ```

        **Transitions.** Transition methods, and the private functions only they call, may set frames directly. When \
        a gesture shares one of those functions, give the gesture its own state and set the frame in layout.

        **Adding a subview or a child view controller.** Add it, call `setNeedsLayout()` on the container, and size \
        it in the container's layout.

        **Layers.** Set model geometry in `layoutSubviews()`. Code that animates only adds `CAAnimation`s.

        **Views that move every frame** (scrolling, dragging). Put them in a small view of their own and invalidate \
        that one, so each `setNeedsLayout()` doesn't re-run a large container's layout.

        **Measuring.** Use `sizeThatFits(_:)`, `systemLayoutSizeFitting(_:)` or `UIHostingController.sizeThatFits(in:)`. \
        Don't set `bounds` to measure.

        **Hiding.** Use `isHidden` or `alpha`, never `frame = .zero`.
        """
    )
}
