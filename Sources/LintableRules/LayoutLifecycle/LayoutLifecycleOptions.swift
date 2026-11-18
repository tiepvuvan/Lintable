import LintableKit

public struct LayoutLifecycleOptions: RuleOptions {
    public var properties = ["frame", "bounds", "center", "position", "anchorPoint"]
    public var checkTransform = false
    public var layoutMethods = [
        "layoutSubviews()",
        "viewWillLayoutSubviews()",
        "viewDidLayoutSubviews()",
        "layoutSublayers(of:)",
        "containerViewWillLayoutSubviews()",
        "containerViewDidLayoutSubviews()",
        "apply(_:)",
        "layout()",
        "viewWillLayout()",
        "viewDidLayout()",
        "resizeSubviews(withOldSize:)",
        "layoutSublayers()",
    ]
    public var exemptTransitions = true
    public var transitionMethods = [
        "animateTransition(using:)",
        "animationEnded(_:)",
        "startInteractiveTransition(_:)",
        "interruptibleAnimator(using:)",
        "presentationTransitionWillBegin()",
        "presentationTransitionDidEnd(_:)",
        "dismissalTransitionWillBegin()",
        "dismissalTransitionDidEnd(_:)",
    ]
    public var exemptSuperclasses = [
        "UICollectionViewLayout",
        "UICollectionViewFlowLayout",
        "UICollectionViewCompositionalLayout",
        "NSCollectionViewLayout",
        "NSCollectionViewFlowLayout",
    ]
    public var helperPrefix = "layout"
    public var deferredCalls = [
        "DispatchQueue.async",
        "DispatchQueue.asyncAfter",
        "Task",
        "Task.detached",
        "Timer.scheduledTimer",
        "RunLoop.perform",
        "OperationQueue.addOperation",
        "NotificationCenter.addObserver",
        "sink",
    ]

    public init() {}
}
