import Foundation

/// A centralized Dependency Injection Container using the Singleton pattern.
/// This acts as the Service Locator for registering and resolving the application's core asynchronous components
/// such as Network Managers, SignalR Clients, ML Inferencers, and Persistence services.
public final class DIContainer {
    
    /// Shared singleton instance
    public static let shared = DIContainer()
    
    /// Internal storage for registered dependencies
    private var dependencies: [String: Any] = [:]
    private let queue = DispatchQueue(label: "com.argonF7.DIContainer", attributes: .concurrent)
    
    private init() {
        // Prevent external instantiation
    }
    
    /// Registers a dependency object mapping it to its formal Type.
    /// - Parameters:
    ///   - type: The protocol or class type to register.
    ///   - dependency: The initialized instance that conforms to or is of the specified type.
    public func register<T>(type: T.Type, dependency: Any) {
        let key = String(describing: type)
        queue.async(flags: .barrier) {
            self.dependencies[key] = dependency
        }
        print("[DIContainer] Registered dependency: \(key)")
    }
    
    /// Resolves a requested dependency by its Type.
    /// - Parameter type: The protocol or class type to resolve.
    /// - Returns: The registered dependency instance, or fatalError if not found.
    public func resolve<T>(type: T.Type) -> T {
        let key = String(describing: type)
        
        var resolvedDependency: Any?
        queue.sync {
            resolvedDependency = dependencies[key]
        }
        
        guard let dependency = resolvedDependency as? T else {
            fatalError("[DIContainer] Failed to resolve dependency for type: \(key). Make sure it was registered.")
        }
        
        return dependency
    }
    
    /// Removes all registered dependencies (mainly useful for teardown during unit testing).
    public func reset() {
        queue.async(flags: .barrier) {
            self.dependencies.removeAll()
        }
    }
}
