import Foundation

/// The reactive brain connecting the F1 Telemetry pipeline linearly to the physical Google Home smart lights.
/// It observes changes in `TrackStatus` and orchestrates complex asynchronous light routines.
public final class HomeAutomationOrchestrator {
    
    private let dslAdapter: GoogleHomeDSLAdapter
    
    // The current active track status determining our state machine
    private var currentSystemStatus: TrackStatus = .allClear
    
    // A concurrency task reference to allow cancellation of an ongoing strobe loop (e.g. Red Flag overriding Yellow)
    private var activeStrobeTask: Task<Void, Never>?
    
    public init(dslAdapter: GoogleHomeDSLAdapter = GoogleHomeDSLAdapter()) {
        self.dslAdapter = dslAdapter
        print("[HomeAutomationOrchestrator] Armed and actively listening for FIA Track Status changes.")
    }
    
    /// Triggered securely by the TelemetryRepository when an official flag is parsed from SignalR.
    public func process(newStatus: TrackStatus) {
        guard newStatus != currentSystemStatus else { return } // Prevent duplicate triggers
        
        // We evaluate transitions using a strict state machine
        print("\n[HomeAutomationOrchestrator] Incident Detected! Transitioning physical room from \(currentSystemStatus.description) -> \(newStatus.description)")
        currentSystemStatus = newStatus
        
        switch newStatus {
        case .yellow, .virtualSafetyCar, .safetyCar:
            triggerCautionRoutine()
            
        case .redFlag:
            triggerCriticalRoutine()
            
        case .allClear:
            triggerAllClearRoutine()
            
        default:
            break
        }
    }
    
    // MARK: - Automation Routines
    
    private func triggerCautionRoutine() {
        // Cancel any pending routines (e.g., if a Yellow flag immediately upgrades to a Red Flag)
        activeStrobeTask?.cancel()
        
        activeStrobeTask = Task {
            // 1. Snapshot the peaceful living room
            await dslAdapter.captureBaseState()
            
            // 2. Begin rhythmic pulsing in Vivid Yellow (#FFD700) using a 1-second interval
            await dslAdapter.executeStrobe(colorHex: "#FFD700", interval: 1.0) { [weak self] in
                // The loop continues until the status is NO LONGER yellow/SC
                guard let self = self else { return true }
                return self.currentSystemStatus == .allClear || self.currentSystemStatus == .redFlag
            }
        }
    }
    
    private func triggerCriticalRoutine() {
        activeStrobeTask?.cancel()
        
        activeStrobeTask = Task {
            // 1. Snapshot the peaceful living room (if it wasn't already captured by a prevailing yellow flag)
            await dslAdapter.captureBaseState()
            
            // 2. Begin aggressive pulsing in Deep Red (#FF0000) using a faster 0.5-second interval
            await dslAdapter.executeStrobe(colorHex: "#FF0000", interval: 0.5) { [weak self] in
                guard let self = self else { return true }
                return self.currentSystemStatus == .allClear
            }
        }
    }
    
    private func triggerAllClearRoutine() {
        // Stop the strobe loops immediately
        activeStrobeTask?.cancel()
        
        Task {
            // 1. Confirm the All-Clear with a bright 5-second sustained Green Wash (#00FF00)
            await dslAdapter.executeSustainedWash(colorHex: "#00FF00", duration: 5.0)
            
            // 2. Revert the actuators flawlessly to the dim, peaceful state captured at the beginning
            await dslAdapter.restoreBaseState()
            print("[HomeAutomationOrchestrator] Room synchronization complete. Resuming normal broadcast viewing.\n")
        }
    }
}
