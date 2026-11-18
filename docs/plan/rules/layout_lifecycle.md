# Rule: `layout_lifecycle`

**Category:** UIKit and AppKit. **Default severity:** warning.

Views get their geometry only during layout. Everywhere else, code changes state
and asks for layout: a gesture handler, a delegate callback, a scroll handler, a
setter or an animation never sets a frame itself.

## Rationale

When one function turns state and bounds into geometry, every reason to lay out
again goes through the same code: rotation, a size class change, window
resizing, Dynamic Type, the first layout. A gesture can't leave a frame computed
from bounds that have since changed, and animating is "change the state, then
animate `layoutIfNeeded()`". It is how UIKit and AppKit are designed to be used:
override `layoutSubviews()` (or `layout()`), invalidate with `setNeedsLayout()`.

## What counts as a layout write

An assignment (`=`, `+=`, `-=`, `*=`, `/=`) whose left side ends in one of the
checked properties, optionally followed by `.origin`, `.size`, `.x`, `.y`,
`.width` or `.height`:

- `frame`, `bounds`, `center`, and a layer's `position` and `anchorPoint`
  (option `properties`);
- `transform` only when `check_transform` is `true`. A rotation or a press-down
  scale doesn't depend on the view's size, so by default it's state that can be
  set anywhere.

An implicit `self` counts (`frame = …` inside a view). These are not writes:

- assignments where the root of the left side is a local variable of the same
  scope (`var frame = view.frame; frame.origin.y = 8`);
- implicit-`self` assignments inside a struct or an enum, which can't be views;
- SwiftUI's `.frame(…)` and other calls.

## Where writes are allowed

1. **Layout methods** (option `layout_methods`), matched by name and labels:
   - UIKit: `layoutSubviews()`, `viewWillLayoutSubviews()`,
     `viewDidLayoutSubviews()`, `layoutSublayers(of:)`,
     `containerViewWillLayoutSubviews()`, `containerViewDidLayoutSubviews()`,
     `apply(_:)` (layout attributes on a reusable view);
   - AppKit: `layout()`, `viewWillLayout()`, `viewDidLayout()`,
     `resizeSubviews(withOldSize:)`;
   - Core Animation: `layoutSublayers()`.
2. **Transition methods**, while `exempt_transitions` is `true` (the default),
   because UIKit hands transitions their start and end frames to animate:
   `animateTransition(using:)`, `animationEnded(_:)`,
   `startInteractiveTransition(_:)`, `interruptibleAnimator(using:)`,
   `presentationTransitionWillBegin()`, `presentationTransitionDidEnd(_:)`,
   `dismissalTransitionWillBegin()`, `dismissalTransitionDidEnd(_:)`.
3. **Layout objects:** anything inside a class whose inheritance clause names one
   of `exempt_superclasses` (default `UICollectionViewLayout`,
   `UICollectionViewFlowLayout`, `UICollectionViewCompositionalLayout`,
   `NSCollectionViewLayout`, `NSCollectionViewFlowLayout`), directly or through a
   class declared in the same file. Their job is computing layout attributes,
   not moving views.
4. **Layout helpers:** a `private` or `fileprivate` function named
   `helper_prefix` followed by an uppercase letter (default `layout`, as in
   `layoutHighlight()`), when every call to it in the file comes from an allowed
   place.
5. **Closures** inside an allowed function, except ones that run later: a closure
   passed to one of `deferred_calls` (default `DispatchQueue.async`,
   `DispatchQueue.asyncAfter`, `DispatchQueue.main.async`, `Task`,
   `Task.detached`, `Timer.scheduledTimer`, `RunLoop.perform`,
   `OperationQueue.addOperation`, `NotificationCenter.addObserver`, `sink`) is
   never allowed.

The rule looks at one file at a time and matches by name, without type
information. That keeps it fast and its answers predictable.

## Messages

| Case | Message |
|---|---|
| A write outside layout | `` `frame` is set in `handlePan(_:)`, outside the layout pass. Store the state, call `setNeedsLayout()`, and set it in `layoutSubviews()` or a private `layout…` helper. `` |
| A helper called from outside layout (reported at the call) | `` `layoutHighlight()` sets geometry and is called from `handlePan(_:)`, outside the layout pass. Call `setNeedsLayout()` instead, and `layoutIfNeeded()` to apply it now. `` |
| A helper that isn't private | `` `layoutHighlight()` must be `private` or `fileprivate` to count as a layout helper. `` |
| A helper used as a value, in `#selector`, or marked `@objc` | `` `layoutHighlight()` can be called from anywhere when it's used as a value or marked `@objc`. Call it only from layout methods. `` |

The JSON and SARIF reporters attach the rule's documentation page to each violation; the messages themselves stay short.

## Options

| Option | Default | Meaning |
|---|---|---|
| `properties` | `[frame, bounds, center, position, anchorPoint]` | Properties whose assignment is a layout write |
| `check_transform` | `false` | Also treat `transform` as a layout write |
| `layout_methods` | the list above | Methods where writes are allowed |
| `exempt_transitions` | `true` | Allow writes in transition methods |
| `transition_methods` | the list above | The methods `exempt_transitions` allows |
| `exempt_superclasses` | the list above | Classes whose subclasses are exempt |
| `helper_prefix` | `layout` | Name prefix for private layout helpers |
| `deferred_calls` | the list above | Calls whose closures run outside layout |

## Examples

Triggering:

```swift
final class ChartView: UIView {
    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        1️⃣highlightLine.center.x = recognizer.location(in: self).x
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        DispatchQueue.main.async {
            2️⃣self.badge.frame = self.bounds
        }
    }
}
```

```swift
final class ToolbarView: UIView {
    func select(_ indexPath: IndexPath) {
        3️⃣layoutIndicator()
    }

    private func layoutIndicator() {
        indicator.frame = indicatorFrame
    }
}
```

Non-triggering:

```swift
final class ChartView: UIView {
    private var highlightedX: CGFloat? {
        didSet { setNeedsLayout() }
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        highlightedX = recognizer.location(in: self).x
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutHighlight()
    }

    private func layoutHighlight() {
        highlightLine.isHidden = highlightedX == nil
        highlightLine.frame = CGRect(x: (highlightedX ?? 0) - 1, y: 0, width: 2, height: bounds.height)
    }
}
```

```swift
final class CardTransition: NSObject, UIViewControllerAnimatedTransitioning {
    func animateTransition(using context: UIViewControllerContextTransitioning) {
        guard let controller = context.viewController(forKey: .to) else { return }
        controller.view.frame = context.finalFrame(for: controller)
    }
}
```

```swift
final class GridLayout: UICollectionViewLayout {
    private func makeAttributes(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes {
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = frame(at: indexPath)
        return attributes
    }
}
```

## How to fix

The documentation page (generated in phase 3, written in phase 4) carries these
recipes, each with before-and-after code:

- **Gesture-driven position:** the handler stores what's highlighted and calls
  `setNeedsLayout()`; a private `layout…` helper called from `layoutSubviews()`
  positions the views.
- **Animated move:** change the state, then
  `UIView.animate { self.layoutIfNeeded() }`. Use
  `UIView.performWithoutAnimation` for the first placement.
- **Keyboard in a presentation controller:** keep the keyboard height; its
  `didSet` calls `containerView?.setNeedsLayout()`; the handler animates
  `containerView?.layoutIfNeeded()`; `containerViewWillLayoutSubviews()` sets
  the presented view's frame.
- **Adding a subview or a child view controller:** add it, call
  `setNeedsLayout()` on the container, and size it in the container's layout.
- **Layers:** set model geometry in `layoutSubviews()`; animation code only adds
  `CAAnimation`s.
- **Views that move every frame** (scrolling, dragging): put them in a small view
  of their own and invalidate that one, so each `setNeedsLayout()` doesn't re-run
  a large container's layout.
- **Measuring:** `sizeThatFits(_:)`, `systemLayoutSizeFitting(…)`, or
  `UIHostingController.sizeThatFits(in:)`; never set `bounds` to measure.
- **Hiding:** `isHidden` or `alpha`, never `frame = .zero`.

## Known limitations

- Without types, any property named `frame`, `bounds`, `center`, `position` or
  `anchorPoint` looks like a view's, for example on a model class. Suppress with
  a directive and a reason, or rename the property.
- A method named like a layout method in a type that isn't a view is still
  treated as one.
- Calls are matched by base name and labels within the file, so two private
  functions with the same name and labels in different types of one file are
  treated as one.
