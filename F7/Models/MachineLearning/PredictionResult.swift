import Foundation

/// Represents the fractional predictions outputted by the Machine Learning inference engines.
public struct PredictionResult: Hashable, Identifiable {
    public let id: String
    
    /// The driver identifier this prediction applies to.
    public let driverNumber: Int
    
    /// The probability of this driver winning the race (0.0 to 1.0) 
    /// primarily calculated by the Gradient Boosting model.
    public let winProbability: Double?
    
    /// The predicted time for the next lap in seconds.
    /// primarily calculated by the Random Forest regressor.
    public let predictedNextLapTime: Double?
    
    /// The confidence interval or MSE metric of the prediction, useful for UI opacity/coloring.
    public let confidenceScore: Double
    
    /// Timestamp of when the inference was executed.
    public let inferenceTimestamp: Date
    
    public init(
        id: String = UUID().uuidString,
        driverNumber: Int,
        winProbability: Double? = nil,
        predictedNextLapTime: Double? = nil,
        confidenceScore: Double = 1.0,
        inferenceTimestamp: Date = Date()
    ) {
        self.id = id
        self.driverNumber = driverNumber
        self.winProbability = winProbability
        self.predictedNextLapTime = predictedNextLapTime
        self.confidenceScore = confidenceScore
        self.inferenceTimestamp = inferenceTimestamp
    }
}
