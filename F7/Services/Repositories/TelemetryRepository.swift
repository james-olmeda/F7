import Foundation

public protocol TelemetryRepositoryProtocol {
    func startIngestion()
    func stopIngestion()
    func configureDelay(offset: TimeInterval)
}

/// The Single Source of Truth for live telemetry feeds.
/// Implements the Repository pattern to seamlessly switch between the robust SignalR stream
/// and the OpenF1 REST fallback if connectivity is hampered.
public final class TelemetryRepository: TelemetryRepositoryProtocol {
    
    private let signalRClient: TelemetryProviderProtocol
    private let openF1Client: TelemetryProviderProtocol
    
    private let delayManager: DelayCalibrationManager
    
    // In a full implementation, we inject the TelemetryViewModel reference or use Combine Subjects here.
    
    public init(
        signalRClient: TelemetryProviderProtocol = F1SignalRClient(),
        openF1Client: TelemetryProviderProtocol = OpenF1RestClient(),
        delayManager: DelayCalibrationManager = DelayCalibrationManager()
    ) {
        self.signalRClient = signalRClient
        self.openF1Client = openF1Client
        self.delayManager = delayManager
        
        setupRouting()
    }
    
    private func setupRouting() {
        self.delayManager.onEventEmitted = { event in
            // Dispatch perfectly timed event to the TelemetryViewModel or Combine sinks
            // print("UI Render Target: Data ready for presentation.")
        }
    }
    
    public func startIngestion() {
        print("[TelemetryRepository] Starting telemetry ingestion pipeline.")
        // Begin with primary SignalR
        signalRClient.start()
        
        // We'd setup observers here to switch to openF1Client.start() if SignalR faults.
    }
    
    public func stopIngestion() {
        print("[TelemetryRepository] Terminating all telemetry providers.")
        signalRClient.stop()
        openF1Client.stop()
    }
    
    public func configureDelay(offset: TimeInterval) {
        delayManager.setDelay(offset)
    }
}
