import XCTest
@testable import Geometrize

final class CoreTests: XCTestCase {

    // fails
    func testHillClimbComparingResultWithCPlusPlus() throws { // swiftlint:disable:this function_body_length
        let url = Bundle.module.url(
            forResource: "hillClimb randomRange",
            withExtension: "txt"
        )
        guard let url else {
            fatalError("Resource \"hillClimb randomRange.txt\" not found in bundle")
        }
        let randomNumbersString = try String(contentsOf: url)
        let lines = randomNumbersString.components(separatedBy: .newlines)
        var counter = 0

        func randomRangeFromFile(in range: ClosedRange<Int>, using generator: inout SplitMix64) -> Int {
            defer { counter += 1 }
            let line = lines[counter]
            let scanner = Scanner(string: line)
            guard
                let random = scanner.scanInt(),
                scanner.scanString("(min:") != nil,
                let theMin = scanner.scanInt(),
                scanner.scanString(",max:") != nil,
                let theMax = scanner.scanInt(),
                theMin == range.lowerBound, theMax == range.upperBound
            else {
                fatalError("Line \(counter + 1) unexpected: \(String(line[..<scanner.currentIndex])). range = \(range)")
            }
            return random
        }
        _randomImplementationReference = randomRangeFromFile
        defer { _randomImplementationReference = _randomImplementation }

        let bitmapTarget = try Bitmap(
            ppmBundleResource: "hillClimb target bitmap",
            withExtension: "ppm"
        )
        let bitmapCurrent = try Bitmap(
            ppmBundleResource: "hillClimb current bitmap",
            withExtension: "ppm"
        )
        var bitmapBuffer = try Bitmap(
            ppmBundleResource: "hillClimb buffer bitmap",
            withExtension: "ppm"
        )
        let bitmapBufferOnExit = try Bitmap(
            ppmBundleResource: "hillClimb buffer bitmap on exit",
            withExtension: "ppm"
        )

        let rectangle = Rectangle(strokeWidth: 1, x1: 281, y1: 193, x2: 309, y2: 225)
        let state = State(score: 0.169823, alpha: 128, shape: rectangle)

        let rectangleOnExit = Rectangle(strokeWidth: 1, x1: 272, y1: 113, x2: 355, y2: 237)
        let stateOnExitSample = State(score: 0.162824, alpha: 128, shape: rectangleOnExit)

        var generator = SplitMix64(seed: 9999)
        let stateOnExit = hillClimb(
            state: state,
            maxAge: 100,
            target: bitmapTarget,
            current: bitmapCurrent,
            buffer: &bitmapBuffer,
            lastScore: 0.170819,
            energyFunction: defaultEnergyFunction,
            using: &generator
        )

        // ("0.15865964089795329") is not equal to ("0.162824") +/- ("1e-06")
        XCTAssertEqual(stateOnExit.score, stateOnExitSample.score, accuracy: 0.000001)
        XCTAssertEqual(stateOnExit.alpha, stateOnExitSample.alpha)
        XCTAssertTrue(stateOnExit.shape == stateOnExitSample.shape) // XCTAssertTrue failed
        XCTAssertEqual(bitmapBuffer, bitmapBufferOnExit) // XCTAssertEqual
    }

}

func == (lhs: any Shape, rhs: any Shape) -> Bool {
    switch (lhs, rhs) {
    case (let lhs as Circle, let rhs as Circle): return lhs == rhs
    case (let lhs as Ellipse, let rhs as Ellipse): return lhs == rhs
    case (let lhs as Line, let rhs as Line): return lhs == rhs
    case (let lhs as Polyline, let rhs as Polyline): return lhs == rhs
    case (let lhs as QuadraticBezier, let rhs as QuadraticBezier): return lhs == rhs
    case (let lhs as Rectangle, let rhs as Rectangle): return lhs == rhs
    case (let lhs as RotatedRectangle, let rhs as RotatedRectangle): return lhs == rhs
    default: return false
    }
}
