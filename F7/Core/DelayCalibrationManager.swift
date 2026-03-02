import Foundation

/// Manages the artificial transmission delay required to synchronize rapid raw telemetry
/// data streams with the significantly slower HLS video broadcasts (e.g. F1TV).
public final class DelayCalibrationManager {
    
    /// The offset in seconds that data is held in cache before emitting to the UI
    public var userConfiguredDelay: TimeInterval
    
    private var eventQueue: [(Date, Any)] = []
    private var timer: Timer?
    
    /// Closure invoked when a specific event reaches its execution time.
    public var onEventEmitted: ((Any) -> Void)?
    
    public init(defaultDelay: TimeInterval = 15.0) {
        self.userConfiguredDelay = defaultDelay
        print("[DelayCalibrationManager] Initialized with offset of \(userConfiguredDelay) seconds.")
        startCheckingQueue()
    }
    
    /// Queues an incoming telemetry object (e.g. CarData, RaceControlMessage) to hold until target time.
    /// - Parameter event: The payload/model to delay.
    public func enqueue(event: Any) {
        let emitTime = Date().addingTimeInterval(userConfiguredDelay)
        eventQueue.append((emitTime, event))
    }
    
    public func setDelay(_ seconds: TimeInterval) {
        print("[DelayCalibrationManager] Adapting sync delay offset to \(seconds)s.")
        self.userConfiguredDelay = max(0, seconds)
    }
    
    private func startCheckingQueue() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            
            // Extract events ready to be broadcasted
            while let first = self.eventQueue.first, first.0 <= now {
                let readyEvent = self.eventQueue.removeFirst().1
                self.onEventEmitted?(readyEvent)
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
