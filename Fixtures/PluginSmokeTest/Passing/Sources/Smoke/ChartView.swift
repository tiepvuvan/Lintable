struct Point {
    var x = 0.0
}

class View {
    var center = Point()
}

final class ChartView: View {
    var highlightedX = 0.0

    func handlePan(to x: Double) {
        highlightedX = x
    }

    func layoutSubviews() {
        center.x = highlightedX
    }
}
