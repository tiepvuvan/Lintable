struct Point {
    var x = 0.0
}

class View {
    var center = Point()
}

final class ChartView: View {
    var highlightedX = 0.0

    func handlePan() {
        center.x = highlightedX
    }
}
