import Foundation
import ActivityKit
import SwiftUI

/// Defines the struct required by iOS 16.1+ to render dynamic Live Activities tracking
/// the race status globally on the Lock Screen and Dynamic Island.
public struct F1LiveActivityAttributes: ActivityAttributes {
    
    /// Static data that defines the activity context (does not change).
    public struct ContentState: Codable, Hashable {
        // Dynamic data that updates via push notifications or background tasks
        public var currentLap: Int
        public var totalLaps: Int
        public var leaderInterval: Double
        public var trackSafetyStatus: String // "Green", "Yellow", "SC"
        public var isVirtualSafetyCar: Bool
    }
    
    // Properties that stay the same for the lifespan of the activity
    public var raceName: String
    public var trackedDriverAcronym: String // e.g., "VER"
    public var teamColorHex: String // e.g., "#0000FF" (Red Bull Blue)
    
    public init(raceName: String, trackedDriverAcronym: String, teamColorHex: String) {
        self.raceName = raceName
        self.trackedDriverAcronym = trackedDriverAcronym
        self.teamColorHex = teamColorHex
    }
}

/// An example of how the Dynamic Island UI is structured, normally this code
/// resides inside a dedicated Widget Extension Target in Xcode.
/*
import WidgetKit

@main
struct F1DynamicIslandWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: F1LiveActivityAttributes.self) { context in
            // Lock Screen Presentation -> Big dashboard
            VStack {
                Text("Formula 1: \(context.attributes.raceName)")
                Text("\(context.attributes.trackedDriverAcronym) Gap: +\(context.state.leaderInterval)s")
            }
        } dynamicIsland: { context in
            // Dynamic Island Presentations
            DynamicIsland {
                // Expanded UI (When user long-presses the island)
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.trackedDriverAcronym)
                        .font(.inter(.headline))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.trackSafetyStatus)
                        .foregroundColor(context.state.trackSafetyStatus == "Yellow" ? .yellow : .green)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Lap \(context.state.currentLap) / \(context.state.totalLaps)")
                        Spacer()
                        Text("+\(context.state.leaderInterval)s")
                            .monospacedDigit()
                    }
                }
            } compactLeading: {
                // Compact UI (Left side of notch)
                Text(context.attributes.trackedDriverAcronym)
                    .foregroundColor(Color(hex: context.attributes.teamColorHex))
            } compactTrailing: {
                // Compact UI (Right side of notch, tiny updates)
                Text(String(format: "%.1f", context.state.leaderInterval))
                    .monospacedDigit()
            } minimal: {
                // Minimal UI (If multiple activities are active)
                Image(systemName: "car.side")
            }
        }
    }
}
*/
