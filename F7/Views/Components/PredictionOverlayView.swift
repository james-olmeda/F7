import SwiftUI

/// An immersive, translucent overlay panel displaying ML inferred predictions.
/// Designed to float gracefully over the F1TV video stream acting as a secondary metrics layer.
public struct PredictionOverlayView: View {
    public let prediction: PredictionResult
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let driverName = DriverInfo.all[prediction.driverNumber]?.abbreviation ?? "DRV \(prediction.driverNumber)"
            Text("LIVE PREDICTION: \(driverName)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Win Probability")
                    .font(.subheadline)
                Spacer()
                
                if let winProb = prediction.winProbability {
                    Text("\(Int(winProb * 100))%")
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundColor(probabilityColor(for: winProb))
                } else {
                    Text("--")
                }
            }
            
            // Minimalist Progress Bar representing momentum
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .frame(width: geometry.size.width, height: 6)
                        .foregroundColor(Color(uiColor: .systemFill))
                    
                    if let prob = prediction.winProbability {
                        RoundedRectangle(cornerRadius: 4)
                            .frame(width: geometry.size.width * CGFloat(prob), height: 6)
                            .foregroundColor(probabilityColor(for: prob))
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: prob)
                    }
                }
            }
            .frame(height: 6)
            
        }
        .padding(16)
        // Apple HIG: Liquid Glass aesthetic
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        // Subtle shadow to lift the panel off the underlying F1TV video stream
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
    
    // Semantic signaling: Green for high probability, Orange/Red for low.
    private func probabilityColor(for prob: Double) -> Color {
        switch prob {
        case 0.7...1.0: return .green
        case 0.3..<0.7: return .orange
        default: return .red
        }
    }
}
