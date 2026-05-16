import SwiftUI

// swiftlint:disable:next type_name
private typealias T = MenuBarLayoutTokens

struct TrafficSparklineView: View {
    private let baseSmoothing: CGFloat = 0.32
    private let minimumCornerSmoothing: CGFloat = 0.2

    let upValues: [Int64]
    let downValues: [Int64]

    var body: some View {
        GeometryReader { geo in
            let maxY = max(1.0, Double(max(self.downValues.max() ?? 0, self.upValues.max() ?? 0)))
            let axisY = floor(geo.size.height * 0.5)
            let upperSpan = max(1, axisY - 2)
            let lowerSpan = max(1, geo.size.height - axisY - 2)
            let maxPoints = 60
            let upContext = SparklinePathContext(
                width: geo.size.width,
                axisY: axisY,
                span: upperSpan,
                maxY: maxY,
                direction: .up,
                maxPoints: maxPoints)
            let downContext = SparklinePathContext(
                width: geo.size.width,
                axisY: axisY,
                span: lowerSpan,
                maxY: maxY,
                direction: .down,
                maxPoints: maxPoints)

            ZStack {
                self.axisPath(width: geo.size.width, axisY: axisY)
                    .stroke(
                        Color(nsColor: .separatorColor).opacity(0.55),
                        style: StrokeStyle(lineWidth: T.stroke, lineCap: .round))

                self.lineAreaPath(for: self.upValues, context: upContext)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(nsColor: .controlAccentColor).opacity(0.30),
                                Color(nsColor: .controlAccentColor).opacity(0.02),
                            ],
                            startPoint: .top,
                            endPoint: .bottom))

                self.lineAreaPath(for: self.downValues, context: downContext)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(nsColor: .systemGreen).opacity(0.32),
                                Color(nsColor: .systemGreen).opacity(0.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom))

                self.linePath(for: self.upValues, context: upContext)
                    .stroke(
                        Color(nsColor: .controlAccentColor).opacity(0.9),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))

                self.linePath(for: self.downValues, context: downContext)
                    .stroke(
                        Color(nsColor: .systemGreen).opacity(0.9),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func linePath(for values: [Int64], context: SparklinePathContext) -> Path {
        var path = Path()
        guard !values.isEmpty else { return path }

        let count = values.count
        let start = self.point(at: 0, in: values, context: context)
        path.move(to: start)

        guard count > 1 else { return path }
        guard count > 2 else {
            path.addLine(to: self.point(at: 1, in: values, context: context))
            return path
        }

        for index in 0..<(count - 1) {
            let previous = self.point(at: max(index - 1, 0), in: values, context: context)
            let current = self.point(at: index, in: values, context: context)
            let next = self.point(at: index + 1, in: values, context: context)
            let following = self.point(at: min(index + 2, count - 1), in: values, context: context)

            let control1 = self.leadingControlPoint(
                previous: previous,
                current: current,
                next: next,
                context: context)
            let control2 = self.trailingControlPoint(
                current: current,
                next: next,
                following: following,
                context: context)

            path.addCurve(to: next, control1: control1, control2: control2)
        }
        return path
    }

    private func lineAreaPath(for values: [Int64], context: SparklinePathContext) -> Path {
        var path = self.linePath(for: values, context: context)
        guard !values.isEmpty else { return path }

        let firstPointX = self.point(at: 0, in: values, context: context).x
        let lastPointX = self.point(at: values.count - 1, in: values, context: context).x
        
        path.addLine(to: CGPoint(x: lastPointX, y: context.axisY))
        path.addLine(to: CGPoint(x: firstPointX, y: context.axisY))
        path.closeSubpath()
        return path
    }

    private func axisPath(width: CGFloat, axisY: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: axisY))
        path.addLine(to: CGPoint(x: width, y: axisY))
        return path
    }

    private func yPosition(
        _ value: Int64,
        axisY: CGFloat,
        span: CGFloat,
        maxY: Double,
        direction: LineDirection) -> CGFloat
    {
        let clamped = max(0.0, min(Double(value), maxY))
        let ratio = CGFloat(clamped / maxY)

        switch direction {
        case .up:
            return axisY - ratio * span
        case .down:
            return axisY + ratio * span
        }
    }

    private func point(at index: Int, in values: [Int64], context: SparklinePathContext) -> CGPoint {
        let clampedIndex = min(max(index, 0), values.count - 1)
        let offsetFromRight = values.count - 1 - clampedIndex
        let x = context.width - (CGFloat(offsetFromRight) / CGFloat(max(context.maxPoints - 1, 1)) * context.width)
        let y = self.yPosition(
            values[clampedIndex],
            axisY: context.axisY,
            span: context.span,
            maxY: context.maxY,
            direction: context.direction)
        return CGPoint(x: x, y: y)
    }

    private func leadingControlPoint(
        previous: CGPoint,
        current: CGPoint,
        next: CGPoint,
        context: SparklinePathContext
    ) -> CGPoint {
        let smoothing = self.cornerSmoothing(previous: previous, current: current, next: next)
        let handleX = (next.x - current.x) * self.baseSmoothing * smoothing
        let tangent = CGPoint(x: next.x - previous.x, y: next.y - previous.y)
        let tangentScale = handleX / max(abs(tangent.x), 0.001)

        return CGPoint(
            x: current.x + handleX,
            y: self.clampedControlY(
                current.y + tangent.y * tangentScale,
                context: context,
                anchors: [previous.y, current.y, next.y]))
    }

    private func trailingControlPoint(
        current: CGPoint,
        next: CGPoint,
        following: CGPoint,
        context: SparklinePathContext
    ) -> CGPoint {
        let smoothing = self.cornerSmoothing(previous: current, current: next, next: following)
        let handleX = (next.x - current.x) * self.baseSmoothing * smoothing
        let tangent = CGPoint(x: following.x - current.x, y: following.y - current.y)
        let tangentScale = handleX / max(abs(tangent.x), 0.001)

        return CGPoint(
            x: next.x - handleX,
            y: self.clampedControlY(
                next.y - tangent.y * tangentScale,
                context: context,
                anchors: [current.y, next.y, following.y]))
    }

    private func cornerSmoothing(previous: CGPoint, current: CGPoint, next: CGPoint) -> CGFloat {
        let incoming = CGPoint(x: current.x - previous.x, y: current.y - previous.y)
        let outgoing = CGPoint(x: next.x - current.x, y: next.y - current.y)
        let incomingLength = hypot(incoming.x, incoming.y)
        let outgoingLength = hypot(outgoing.x, outgoing.y)

        guard incomingLength > 0.001, outgoingLength > 0.001 else { return 1 }

        let cosine = ((incoming.x * outgoing.x) + (incoming.y * outgoing.y)) / (incomingLength * outgoingLength)
        let normalized = (max(-1, min(1, cosine)) + 1) * 0.5
        return self.minimumCornerSmoothing + ((1 - self.minimumCornerSmoothing) * normalized)
    }

    private func clampedControlY(
        _ value: CGFloat,
        context: SparklinePathContext,
        anchors: [CGFloat]
    ) -> CGFloat {
        let bounds = self.verticalBounds(for: context)
        let localBounds = self.anchorBounds(anchors).clamped(to: bounds)
        return min(max(value, localBounds.lowerBound), localBounds.upperBound)
    }

    private func anchorBounds(_ anchors: [CGFloat]) -> ClosedRange<CGFloat> {
        let minimum = anchors.min() ?? 0
        let maximum = anchors.max() ?? minimum
        return minimum...maximum
    }

    private func verticalBounds(for context: SparklinePathContext) -> ClosedRange<CGFloat> {
        switch context.direction {
        case .up:
            return (context.axisY - context.span)...context.axisY
        case .down:
            return context.axisY...(context.axisY + context.span)
        }
    }

    private struct SparklinePathContext {
        let width: CGFloat
        let axisY: CGFloat
        let span: CGFloat
        let maxY: Double
        let direction: LineDirection
        let maxPoints: Int
    }

    private enum LineDirection {
        case up
        case down
    }
}
