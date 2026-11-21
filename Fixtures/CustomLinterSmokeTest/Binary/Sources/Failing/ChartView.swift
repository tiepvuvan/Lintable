class UIView {}

final class ChartView: UIView {
    var renderCount = 0

    func render() {
        renderCount += 1
        print("rendered", renderCount)
    }
}
