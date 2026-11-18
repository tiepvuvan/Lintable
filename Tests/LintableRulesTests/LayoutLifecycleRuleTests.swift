import LintableRules
import LintableTesting
import Testing

@Suite struct LayoutLifecycleExampleTests {
    @Test func examplesAreCorrect() {
        verifyExamples(of: LayoutLifecycleRule.self)
    }
}

@Suite struct LayoutLifecycleAllowedTests {
    @Test(arguments: [
        "override func layoutSubviews()",
        "override func viewWillLayoutSubviews()",
        "override func viewDidLayoutSubviews()",
        "func layoutSublayers(of layer: CALayer)",
        "override func containerViewWillLayoutSubviews()",
        "override func containerViewDidLayoutSubviews()",
        "override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes)",
        "override func layout()",
        "override func viewWillLayout()",
        "override func viewDidLayout()",
        "override func resizeSubviews(withOldSize oldSize: NSSize)",
        "override func layoutSublayers()",
    ])
    func layoutMethods(signature: String) {
        assertLint(LayoutLifecycleRule.self, """
        final class Host: UIView {
            \(signature) {
                badge.frame = bounds
            }
        }
        """)
    }

    @Test(arguments: [
        "func animateTransition(using context: UIViewControllerContextTransitioning)",
        "func animationEnded(_ completed: Bool)",
        "func startInteractiveTransition(_ context: UIViewControllerContextTransitioning)",
        "func interruptibleAnimator(using context: UIViewControllerContextTransitioning)",
        "override func presentationTransitionWillBegin()",
        "override func presentationTransitionDidEnd(_ completed: Bool)",
        "override func dismissalTransitionWillBegin()",
        "override func dismissalTransitionDidEnd(_ completed: Bool)",
    ])
    func transitionMethods(signature: String) {
        assertLint(LayoutLifecycleRule.self, """
        final class Transition: NSObject {
            \(signature) {
                snapshot.frame = finalFrame
            }
        }
        """)
    }

    @Test func transitionsAreReportedWhenNotExempt() {
        assertLint(LayoutLifecycleRule.self, options: "exempt_transitions: false", """
        final class Transition: NSObject {
            func animateTransition(using context: UIViewControllerContextTransitioning) {
                1️⃣snapshot.frame = finalFrame
            }
        }
        """)
    }

    @Test func helpersCalledOnlyFromLayoutAndFromEachOther() {
        assertLint(LayoutLifecycleRule.self, """
        final class Host: UIView {
            override func layoutSubviews() {
                super.layoutSubviews()
                layoutBadge()
            }

            private func layoutBadge() {
                badge.frame = bounds
                layoutDot()
            }

            fileprivate func layoutDot() {
                dot.center = badge.center
            }
        }
        """)
    }

    @Test func helpersInAPrivateTypeAreFilePrivate() {
        assertLint(LayoutLifecycleRule.self, """
        private final class Host: UIView {
            override func layoutSubviews() {
                super.layoutSubviews()
                layoutBadge()
            }

            func layoutBadge() {
                badge.frame = bounds
            }
        }
        """)
    }

    @Test func layoutObjectsThroughAnExtensionAndASubclass() {
        assertLint(LayoutLifecycleRule.self, """
        class Base: UICollectionViewFlowLayout {}
        final class Grid: Base {}
        extension Grid {
            func pin(_ attributes: UICollectionViewLayoutAttributes) {
                attributes.frame.origin.y = 0
            }
        }
        """)
    }
}

@Suite struct LayoutLifecycleReportedTests {
    @Test func everyKindOfContext() {
        assertLint(LayoutLifecycleRule.self, """
        final class Host: UIView {
            var progress: CGFloat = 0 {
                didSet { 1️⃣bar.frame.size.width = bounds.width * progress }
            }

            var offset: CGFloat {
                get { 0 }
                set { 2️⃣bar.frame.origin.x = newValue }
            }

            override init(frame: CGRect) {
                super.init(frame: frame)
                3️⃣bar.frame = bounds
            }

            override func viewDidLoad() {
                4️⃣bar.frame = bounds
            }

            @objc private func didTap() {
                UIView.animate(withDuration: 0.3) {
                    5️⃣self.bar.frame = .zero
                }
            }

            func setProgress(_ value: CGFloat) {
                6️⃣bar.bounds.size = CGSize(width: value, height: 4)
            }
        }
        """, messages: [
            "1️⃣": "`frame.size.width` is set in the `didSet` of `progress`, outside the layout pass. Store the state, call `setNeedsLayout()`, and set it in `layoutSubviews()` or a private `layout…` helper.",
            "2️⃣": "`frame.origin.x` is set in the `set` of `offset`, outside the layout pass. Store the state, call `setNeedsLayout()`, and set it in `layoutSubviews()` or a private `layout…` helper.",
            "3️⃣": "`frame` is set in `init(frame:)`, outside the layout pass. Store the state, call `setNeedsLayout()`, and set it in `layoutSubviews()` or a private `layout…` helper.",
            "5️⃣": "`frame` is set in `didTap()`, outside the layout pass. Store the state, call `setNeedsLayout()`, and set it in `layoutSubviews()` or a private `layout…` helper.",
        ])
    }

    @Test(arguments: [
        "DispatchQueue.main.async",
        "DispatchQueue.global().async",
        "DispatchQueue.main.asyncAfter(deadline: .now() + 1)",
        "Task",
        "Task.detached",
        "Timer.scheduledTimer(withTimeInterval: 1, repeats: false)",
        "RunLoop.main.perform",
        "OperationQueue.main.addOperation",
        "NotificationCenter.default.addObserver(forName: .changed, object: nil, queue: .main)",
        "publisher.sink",
    ])
    func deferredClosuresInsideLayout(call: String) {
        assertLint(LayoutLifecycleRule.self, """
        final class Host: UIView {
            override func layoutSubviews() {
                super.layoutSubviews()
                \(call) { _ in
                    1️⃣self.badge.frame = self.bounds
                }
            }
        }
        """)
    }

    @Test func topLevelAndPropertyInitializers() {
        assertLint(LayoutLifecycleRule.self, """
        1️⃣view.frame = .zero

        final class Host: UIView {
            let badge: UIView = {
                let view = UIView()
                2️⃣view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
                return view
            }()
        }
        """, messages: [
            "1️⃣": "`frame` is set in top-level code, outside the layout pass. Store the state, call `setNeedsLayout()`, and set it in `layoutSubviews()` or a private `layout…` helper.",
            "2️⃣": "`frame` is set in the initial value of `badge`, outside the layout pass. Store the state, call `setNeedsLayout()`, and set it in `layoutSubviews()` or a private `layout…` helper.",
        ])
    }
}

@Suite struct LayoutLifecycleHelperTests {
    @Test func aHelperCalledFromAnActionIsReportedAtTheCall() {
        assertLint(LayoutLifecycleRule.self, """
        final class Host: UIView {
            override func layoutSubviews() {
                super.layoutSubviews()
                layoutBadge()
            }

            @objc private func didTap() {
                1️⃣layoutBadge()
            }

            private func layoutBadge() {
                badge.frame = bounds
            }
        }
        """, messages: [
            "1️⃣": "`layoutBadge()` sets geometry and is called from `didTap()`, outside the layout pass. Call `setNeedsLayout()` instead, and `layoutIfNeeded()` to apply it now.",
        ])
    }

    @Test func aHelperCalledOnlyFromAnotherBadHelperIsReportedOnce() {
        assertLint(LayoutLifecycleRule.self, """
        final class Host: UIView {
            func refresh() {
                1️⃣layoutOuter()
            }

            private func layoutOuter() {
                layoutInner()
            }

            private func layoutInner() {
                badge.frame = bounds
            }
        }
        """)
    }

    @Test func aNonPrivateHelperIsReportedAtItsName() {
        assertLint(LayoutLifecycleRule.self, """
        final class Host: UIView {
            override func layoutSubviews() {
                super.layoutSubviews()
                layoutBadge()
            }

            func 1️⃣layoutBadge() {
                badge.frame = bounds
                badge.center.x = 0
            }
        }
        """, messages: ["1️⃣": "`layoutBadge()` must be `private` or `fileprivate` to count as a layout helper."])
    }

    @Test func valueUsesAndObjCHelpers() {
        assertLint(LayoutLifecycleRule.self, """
        final class Host: UIView {
            override func layoutSubviews() {
                super.layoutSubviews()
                layoutBadge()
                layoutDot()
            }

            func setUp() {
                schedule(1️⃣layoutBadge)
            }

            private func layoutBadge() {
                badge.frame = bounds
            }

            @objc private func 2️⃣layoutDot() {
                dot.frame = bounds
            }
        }
        """)
    }

    @Test func namesThatAreNotHelpers() {
        assertLint(LayoutLifecycleRule.self, """
        final class Host: UIView {
            private func layoutbar() {
                1️⃣bar.frame = bounds
            }

            private func relayout() {
                2️⃣bar.frame = bounds
            }

            override func layoutMarginsDidChange() {
                3️⃣bar.frame = bounds
            }
        }
        """)
    }

    @Test func anUnusedHelperIsQuiet() {
        assertLint(LayoutLifecycleRule.self, """
        final class Host: UIView {
            private func layoutBadge() {
                badge.frame = bounds
            }
        }
        """)
    }
}

@Suite struct LayoutLifecycleTransitionHelperTests {
    @Test func privateFunctionsCalledOnlyFromTransitionsArePartOfThem() {
        assertLint(LayoutLifecycleRule.self, """
        final class SheetTransition: NSObject, UIViewControllerAnimatedTransitioning {
            func animateTransition(using context: UIViewControllerContextTransitioning) {
                guard let sheet = context.view(forKey: .to) else { return }
                slideIn(sheet, in: context)
            }

            fileprivate func settle(_ sheet: UIView) {
                sheet.center.y = sheet.superview?.bounds.midY ?? 0
            }

            private func slideIn(_ sheet: UIView, in context: UIViewControllerContextTransitioning) {
                sheet.frame = context.containerView.bounds.offsetBy(dx: 0, dy: context.containerView.bounds.height)
                UIView.animate(withDuration: 0.3, animations: {
                    sheet.frame = context.containerView.bounds
                    layoutShadow(below: sheet)
                }, completion: { _ in
                    settle(sheet)
                    context.completeTransition(!context.transitionWasCancelled)
                })
            }

            private func layoutShadow(below sheet: UIView) {
                shadow.frame = sheet.frame.insetBy(dx: -8, dy: -8)
            }
        }

        final class SheetPresentationController: UIPresentationController {
            override func presentationTransitionWillBegin() {
                guard let snapshot = installSnapshot(frame: containerView?.bounds ?? .zero) else { return }
                snapshot.alpha = 0.8
            }

            override func dismissalTransitionWillBegin() {
                guard let snapshot = installSnapshot(frame: frameOfPresentedViewInContainerView) else { return }
                snapshot.alpha = 1
            }

            private func installSnapshot(frame: CGRect) -> UIView? {
                let snapshot = presentingViewController.view.snapshotView(afterScreenUpdates: false)
                snapshot?.frame = frame
                return snapshot
            }
        }
        """)
    }

    @Test func aFunctionAlsoCalledOutsideATransitionIsReported() {
        assertLint(LayoutLifecycleRule.self, """
        final class CardPresentationController: UIPresentationController {
            override func presentationTransitionWillBegin() {
                moveCard(to: frameOfPresentedViewInContainerView)
            }

            override func dismissalTransitionDidEnd(_ completed: Bool) {
                DispatchQueue.main.async {
                    self.restore()
                }
            }

            @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
                moveCard(to: frameOfPresentedViewInContainerView.offsetBy(dx: 0, dy: recognizer.translation(in: containerView).y))
            }

            private func moveCard(to frame: CGRect) {
                1️⃣presentedView?.frame = frame
            }

            private func restore() {
                2️⃣presentingViewController.view.frame = containerView?.bounds ?? .zero
            }
        }
        """, messages: [
            "1️⃣": "`frame` is set in `moveCard(to:)`, outside the layout pass. Store the state, call `setNeedsLayout()`, and set it in `layoutSubviews()` or a private `layout…` helper.",
            "2️⃣": "`frame` is set in `restore()`, outside the layout pass. Store the state, call `setNeedsLayout()`, and set it in `layoutSubviews()` or a private `layout…` helper.",
        ])
    }

    @Test func onlyPrivateFunctionsThatAreOnlyCalled() {
        assertLint(LayoutLifecycleRule.self, """
        final class FadeTransition: NSObject, UIViewControllerAnimatedTransitioning {
            func animateTransition(using context: UIViewControllerContextTransitioning) {
                guard let view = context.view(forKey: .to) else { return }
                reset()
                place(view, in: context)
                UIView.animate(withDuration: 0.2, animations: { view.alpha = 1 }, completion: finish)
            }

            func place(_ view: UIView, in context: UIViewControllerContextTransitioning) {
                1️⃣view.frame = context.containerView.bounds
            }

            private func finish(_ finished: Bool) {
                2️⃣snapshot.frame = initialFrame
            }

            @objc private func reset() {
                3️⃣snapshot.frame = initialFrame
            }
        }
        """)
    }

    @Test func helpersAreReportedWhenTransitionsAreNotExempt() {
        assertLint(LayoutLifecycleRule.self, options: "exempt_transitions: false", """
        final class SheetTransition: NSObject, UIViewControllerAnimatedTransitioning {
            func animateTransition(using context: UIViewControllerContextTransitioning) {
                guard let sheet = context.view(forKey: .to) else { return }
                slideIn(sheet, to: context.containerView.bounds)
            }

            private func slideIn(_ sheet: UIView, to frame: CGRect) {
                1️⃣sheet.frame = frame
            }
        }
        """)
    }
}

@Suite struct LayoutLifecycleWriteTests {
    @Test func whatCountsAsAWrite() {
        assertLint(LayoutLifecycleRule.self, """
        final class Host: UIView {
            func update() {
                1️⃣badge.center.x = 4
                2️⃣badge.frame.origin.y += 8
                3️⃣badge.bounds.size = .zero
                4️⃣badge.layer.position = .zero
                5️⃣badge.layer.anchorPoint = .zero
                6️⃣badge?.frame = .zero
                7️⃣frame = .zero
                8️⃣self.center = .zero
                9️⃣items[0].frame = .zero
            }
        }
        """)
    }

    @Test func whatDoesNot() {
        assertLint(LayoutLifecycleRule.self, """
        final class Host: UIView {
            func update(frame: CGRect) {
                var bounds = self.bounds
                bounds.origin.y = 8
                if frame == .zero {
                    badge.transform = .identity
                }
                badge.frame.origin.debugDescription.append("x")
                let view = Text("A").frame(width: 10, height: 10)
                badge.tag = 1
            }
        }
        """)
    }

    @Test func transformWhenAskedFor() {
        assertLint(LayoutLifecycleRule.self, options: "check_transform: true", """
        final class Host: UIView {
            func spin() {
                1️⃣chevron.transform = CGAffineTransform(rotationAngle: .pi)
            }
        }
        """)
    }
}

@Suite struct LayoutLifecycleOptionTests {
    @Test func customProperties() {
        assertLint(LayoutLifecycleRule.self, options: "properties: [origin]", """
        final class Host: UIView {
            func move() {
                1️⃣marker.origin = .zero
                marker.frame = .zero
            }
        }
        """)
    }

    @Test func customLayoutMethods() {
        assertLint(LayoutLifecycleRule.self, options: "layout_methods: [arrange()]", """
        final class Host: UIView {
            func arrange() {
                badge.frame = bounds
            }

            override func layoutSubviews() {
                1️⃣badge.frame = bounds
            }
        }
        """)
    }

    @Test func customExemptSuperclasses() {
        assertLint(LayoutLifecycleRule.self, options: "exempt_superclasses: [BoardLayout]", """
        final class Board: BoardLayout {
            func place() {
                tile.frame = .zero
            }
        }

        final class Grid: UICollectionViewLayout {
            func place() {
                1️⃣attributes.frame = .zero
            }
        }
        """)
    }

    @Test func customHelperPrefix() {
        assertLint(LayoutLifecycleRule.self, options: "helper_prefix: place", """
        final class Host: UIView {
            override func layoutSubviews() {
                super.layoutSubviews()
                placeBadge()
                layoutDot()
            }

            private func placeBadge() {
                badge.frame = bounds
            }

            private func layoutDot() {
                1️⃣dot.frame = bounds
            }
        }
        """)
    }

    @Test func customDeferredCalls() {
        assertLint(LayoutLifecycleRule.self, options: "deferred_calls: [later]", """
        final class Host: UIView {
            override func layoutSubviews() {
                super.layoutSubviews()
                later {
                    1️⃣badge.frame = bounds
                }
                DispatchQueue.main.async {
                    badge.frame = bounds
                }
            }
        }
        """)
    }
}
