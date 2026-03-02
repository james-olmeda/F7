import Foundation

/// A REST client fallback that queries OpenF1 APIs for telemetry when SignalR fails.
public final class OpenF1RestClient: TelemetryProviderProtocol {
    private let baseURL = "https://api.openf1.org/v1"
    private var pollingTimer: Timer?
    public var isConnected: Bool = false
    
    public init() {
        print("[OpenF1RestClient] Initialized external fallback API structure.")
    }
    
    public func start() {
        print("[OpenF1RestClient] Commencing REST polling fallback.")
        isConnected = true
        
        // Simulating a polling structure since OpenF1 provides REST endpoints, not webSockets typically
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.fetchLatestTelemetry()
        }
    }
    
    public func stop() {
        print("[OpenF1RestClient] Halting OpenF1 periodic polling.")
        pollingTimer?.invalidate()
        pollingTimer = nil
        isConnected = false
    }
    
    private func fetchLatestTelemetry() {
        guard let url = URL(string: "\(baseURL)/car_data?session_key=latest") else { return }
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, 
                      (200...299).contains(httpResponse.statusCode) else {
                    return
                }
                
                print("[OpenF1RestClient] Extracted \(data.count) bytes of historical telemetry.")
                // Parse the data and dispatch to Repository
            } catch {
                print("[OpenF1RestClient] Failed to fetch REST telemetry: \(error)")
            }
        }
    }
}
