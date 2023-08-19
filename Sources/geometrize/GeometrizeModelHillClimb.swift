import Foundation

/// The model class is the model for the core optimization/fitting algorithm.
struct GeometrizeModelHillClimb {

    /// Creates a model that will aim to replicate the target bitmap with shapes.
    /// - Parameter targetBitmap: The target bitmap to replicate with shapes.
    init(targetBitmap: Bitmap) {
        self.targetBitmap = targetBitmap
        currentBitmap = Bitmap(width: targetBitmap.width, height: targetBitmap.height, color: targetBitmap.averageColor())
        lastScore = differenceFull(first: targetBitmap, second: currentBitmap)
        baseRandomSeed = 0
        randomSeedOffset = 0
    }

    /// Creates a model that will optimize for the given target bitmap, starting from the given initial bitmap.
    /// The target bitmap and initial bitmap must be the same size (width and height).
    /// - Parameters:
    ///   - target: The target bitmap to replicate with shapes.
    ///   - initial: The starting bitmap.
    init(target: Bitmap, initial: Bitmap) {
        targetBitmap = target
        currentBitmap = initial
        lastScore = differenceFull(first: target, second: currentBitmap)
        baseRandomSeed = 0
        randomSeedOffset = 0
        assert(target.width == currentBitmap.width)
        assert(target.height == currentBitmap.height)
    }

    /// Resets the model back to the state it was in when it was created.
    /// - Parameter backgroundColor: The starting background color to use.
    mutating func reset(backgroundColor: Rgba) {
        currentBitmap.fill(color: backgroundColor)
        lastScore = differenceFull(first: targetBitmap, second: currentBitmap)
    }

    var width: Int { targetBitmap.width }
    var height: Int { targetBitmap.height }

    private mutating func getHillClimbState( // swiftlint:disable:this function_parameter_count
        shapeCreator: () -> any Shape,
        alpha: UInt8,
        shapeCount: Int,
        maxShapeMutations: Int,
        maxThreads: Int, // Ignored. Single thread is used at the moment.
        energyFunction: @escaping EnergyFunction
    ) -> [State] {
        // Ensure that the results of the random generation are the same between tasks with identical settings
        // The RNG is thread-local and std::async may use a thread pool (which is why this is necessary)
        // Note this implementation requires maxThreads to be the same between tasks for each task to produce the same results.
        let seed = baseRandomSeed + randomSeedOffset
        randomSeedOffset += 1
        seedRandomGenerator(UInt64(seed))

        let lastScore = lastScore

        var buffer: Bitmap = currentBitmap
        let state = bestHillClimbState(
            shapeCreator: shapeCreator,
            alpha: UInt(alpha),
            n: shapeCount,
            age: maxShapeMutations,
            target: targetBitmap,
            current: currentBitmap,
            buffer: &buffer,
            lastScore: lastScore,
            energyFunction: energyFunction
        )

        return [state]
    }

    /// Steps the primitive optimization/fitting algorithm.
    /// - Parameters:
    ///   - shapeCreator: A function that will produce the shapes.
    ///   - alpha: The alpha of the shape.
    ///   - shapeCount: The number of random shapes to generate (only 1 is chosen in the end).
    ///   - maxShapeMutations: The maximum number of times to mutate each random shape.
    ///   - maxThreads: The maximum number of threads to use during this step.
    ///   - energyFunction: A function to calculate the energy.
    ///   - addShapePrecondition: A function to determine whether to accept a shape.
    /// - Returns: A vector containing data about the shapes added to the model in this step.
    ///     This may be empty if no shape that improved the image could be found.
    mutating func step( // swiftlint:disable:this function_parameter_count
        shapeCreator: () -> any Shape,
        alpha: UInt8,
        shapeCount: Int,
        maxShapeMutations: Int,
        maxThreads: Int,
        energyFunction: @escaping EnergyFunction,
        addShapePrecondition: @escaping ShapeAcceptancePreconditionFunction = defaultAddShapePrecondition
    ) -> [ShapeResult] {

        let states: [State] = getHillClimbState(
            shapeCreator: shapeCreator,
            alpha: alpha,
            shapeCount: shapeCount,
            maxShapeMutations: maxShapeMutations,
            maxThreads: maxThreads,
            energyFunction: energyFunction
        )

        guard !states.isEmpty else {
            fatalError("Failed to get a hill climb state.")
        }

        // State with min score
        guard let it = states.min(by: { $0.score < $1.score }) else {
            fatalError("Failed to get a state with min score.")
        }

        // Draw the shape onto the image
        let shape = it.shape.copy()
        let lines: [Scanline] = shape.rasterize()
        let color: Rgba = computeColor(target: targetBitmap, current: currentBitmap, lines: lines, alpha: alpha)
        let before: Bitmap = currentBitmap
        currentBitmap.draw(lines: lines, color: color)

        // Check for an improvement - if not, roll back and return no result
        let newScore: Double = differencePartial(target: targetBitmap, before: before, after: currentBitmap, score: lastScore, lines: lines)
        guard addShapePrecondition(lastScore, newScore, shape, lines, color, before, currentBitmap, targetBitmap) else {
            currentBitmap = before
            return []
        }

        // Improvement - set new baseline and return the new shape
        lastScore = newScore

        let result: ShapeResult = ShapeResult(score: lastScore, color: color, shape: shape)
        return [result]
    }

    /// Draws a shape on the model. Typically used when to manually add a shape to the image (e.g. when setting an initial background).
    /// NOTE this unconditionally draws the shape, even if it increases the difference between the source and target image.
    /// - Parameters:
    ///   - shape: The shape to draw.
    ///   - color: The color (including alpha) of the shape.
    /// - Returns: Data about the shape drawn on the model.
    mutating func draw(shape: any Shape, color: Rgba) -> ShapeResult {
        let lines: [Scanline] = shape.rasterize()
        let before: Bitmap = currentBitmap
        currentBitmap.draw(lines: lines, color: color)
        lastScore = differencePartial(target: targetBitmap, before: before, after: currentBitmap, score: lastScore, lines: lines)
        return ShapeResult(score: lastScore, color: color, shape: shape)
    }

    /// Gets the target bitmap.
    /// - Returns: The target bitmap.
    func getTarget() -> Bitmap { targetBitmap }

    /// Sets the seed that the random number generators of this model use.
    /// Note that the model also uses an internal seed offset which is incremented when the model is stepped.
    /// - Parameter seed: The random number generator seed.
    mutating func setSeed(_ seed: Int) {
        baseRandomSeed = seed
    }

    /// The target bitmap, the bitmap we aim to approximate.
    private var targetBitmap: Bitmap

    /// The current bitmap.
    var currentBitmap: Bitmap

    /// Score derived from calculating the difference between bitmaps.
    var lastScore: Double

    private static let defaultMaxThreads: Int = 4

    /// The base value used for seeding the random number generator (the one the user has control over)
    var baseRandomSeed: Int // TODO: atomic

    /// Seed used for random number generation.
    /// Note: incremented by each std::async call used for model stepping.
    var randomSeedOffset: Int // TODO: atomic

}