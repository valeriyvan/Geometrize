import XCTest
@testable import Geometrize

final class CoreTests: XCTestCase {

    func testDifferenceFull() throws {
        let blackBitmap = Bitmap(width: 10, height: 10, color: .black)

        // Difference with itself is 0
        XCTAssertEqual(blackBitmap.differenceFull(with: blackBitmap), 0)

        var blackBitmapOnePixelChanged = blackBitmap
        blackBitmapOnePixelChanged[0, 0] = .white
        var blackBitmapTwoPixelsChanged = blackBitmapOnePixelChanged
        blackBitmapTwoPixelsChanged[0, 1] = .white

        // Changing two pixels means there's more difference than changing one.
        XCTAssertGreaterThan(
            blackBitmap.differenceFull(with: blackBitmapTwoPixelsChanged),
            blackBitmap.differenceFull(with: blackBitmapOnePixelChanged)
        )

        // Now the same for white image
        let whiteBitmap = Bitmap(width: 10, height: 10, color: .white)

        // Difference with itself is 0
        XCTAssertEqual(whiteBitmap.differenceFull(with: whiteBitmap), 0)

        var whiteBitmapOnePixelChanged = whiteBitmap
        whiteBitmapOnePixelChanged[0, 0] = .black
        var whiteBitmapTwoPixelsChanged = whiteBitmapOnePixelChanged
        whiteBitmapTwoPixelsChanged[0, 1] = .black

        // Changing two pixels means there's more difference than changing one.
        XCTAssertGreaterThan(
            whiteBitmap.differenceFull(with: whiteBitmapTwoPixelsChanged),
            whiteBitmap.differenceFull(with: whiteBitmapOnePixelChanged)
        )
    }

    func testDifferenceFullComparingResultWithCPlusPlus() throws {
        let bitmapFirst = try Bitmap(ppmBundleResource: "differenceFull bitmap first", withExtension: "ppm")
        let bitmapSecond = try Bitmap(ppmBundleResource: "differenceFull bitmap second", withExtension: "ppm")
        XCTAssertEqual(bitmapFirst.differenceFull(with: bitmapSecond), 0.170819, accuracy: 0.000001)
    }

    func testDifferencePartialComparingResultWithCPlusPlus() throws {
        let bitmapTarget = try Bitmap(ppmBundleResource: "differencePartial bitmap target", withExtension: "ppm")
        let bitmapBefore = try Bitmap(ppmBundleResource: "differencePartial bitmap before", withExtension: "ppm")
        let bitmapAfter = try Bitmap(ppmBundleResource: "differencePartial bitmap after", withExtension: "ppm")
        let scanlines = try [Scanline](stringBundleResource: "differencePartial scanlines", withExtension: "txt")
        XCTAssertEqual(
            bitmapBefore.differencePartial(
                with: bitmapAfter,
                target: bitmapTarget,
                score: 0.170819,
                mask: scanlines
            ),
            0.170800,
            accuracy: 0.000001
        )
    }

    func testDefaultEnergyFunctionComparingResultWithCPlusPlus() throws {
        let scanlines = try [Scanline](
            stringBundleResource: "defaultEnergyFunction scanlines",
            withExtension: "txt"
        )
        let bitmapTarget = try Bitmap(
            ppmBundleResource: "defaultEnergyFunction target bitmap",
            withExtension: "ppm"
        )
        let bitmapCurrent = try Bitmap(
            ppmBundleResource: "defaultEnergyFunction current bitmap",
            withExtension: "ppm"
        )
        var bitmapBuffer = try Bitmap(
            ppmBundleResource: "defaultEnergyFunction buffer bitmap",
            withExtension: "ppm"
        )
        let bitmapBufferOnExit = try Bitmap(
            ppmBundleResource: "defaultEnergyFunction buffer bitmap on exit",
            withExtension: "ppm"
        )

        XCTAssertEqual(
            defaultEnergyFunction(
                scanlines,
                128 /* alpha */,
                bitmapTarget,
                bitmapCurrent,
                &bitmapBuffer,
                0.162824
            ),
            0.162776,
            accuracy: 0.000001
        )

        XCTAssertEqual(bitmapBuffer, bitmapBufferOnExit)
    }

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
