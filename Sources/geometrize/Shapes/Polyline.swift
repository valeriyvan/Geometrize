import Foundation

public final class Polyline: Shape {
    public var points: [Point<Double>]

    public init() {
        points = []
    }

    public init(points: [Point<Double>]) {
        self.points = points
    }

    public func copy() -> Polyline {
        Polyline(points: points)
    }

    public func setup(x xRange: ClosedRange<Int>, y yRange: ClosedRange<Int>, using generator: inout SplitMix64) {
        let range32 = -32...32
        let startingPoint = Point(
            x: Int._random(in: xRange, using: &generator),
            y: Int._random(in: yRange, using: &generator)
        )
        var points: [Point<Double>] = []
        for _ in 0..<4 {
            points.append(
                Point(
                    x: Double((startingPoint.x + Int._random(in: range32, using: &generator)).clamped(to: xRange)),
                    y: Double((startingPoint.y + Int._random(in: range32, using: &generator)).clamped(to: yRange))
                )
            )
        }
        self.points = points
    }

    public func mutate(x xRange: ClosedRange<Int>, y yRange: ClosedRange<Int>, using generator: inout SplitMix64) {
        let i = Int._random(in: 0...points.count-1, using: &generator)
        var point = points[i]
        let range64 = -64...64
        point.x = Double((Int(point.x) + Int._random(in: range64, using: &generator)).clamped(to: xRange))
        point.y = Double((Int(point.y) + Int._random(in: range64, using: &generator)).clamped(to: yRange))
        points[i] = point
    }

    public func rasterize(x xRange: ClosedRange<Int>, y yRange: ClosedRange<Int>) -> [Scanline] {
        var lines: [Scanline] = []
        // Prevent scanline overlap, it messes up the energy functions that rely on the scanlines not intersecting themselves
        var duplicates: Set<Point<Int>> = Set()
        for i in 0..<points.count {
            let p0 = points[i]
            let p1 = i < points.count - 1 ? points[i + 1] : p0
            let points = drawThickLine(from: Point<Int>(p0), to: Point<Int>(p1))
            for point in points {
                if !duplicates.contains(point) {
                    duplicates.insert(point)
                    if let trimmed = Scanline(y: point.y, x1: point.x, x2: point.x).trimmed(x: xRange, y: yRange) {
                        lines.append(trimmed)
                    }
                }
            }
        }
        if lines.isEmpty {
            print("Warning: \(#function) produced no scanlines.")
        }
        return lines
    }

    public var description: String {
        "Polyline(" + points.map(\.description).joined(separator: ", ") + ")"
    }

}
