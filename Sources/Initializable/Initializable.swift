// The Swift Programming Language
// https://docs.swift.org/swift-book
//
//  Initializable.swift
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation

public protocol Initializable {
    var gate: InitializationGate { get }
}

public extension Initializable {
    var initialized: Bool {
        get async {
            if case .initialized = await gate.state { return true }
            return false
        }
    }
    
    func markInitialized() async { await gate.markInitialized() }
    
    func awaitInitialized() async { await gate.wait() }
}

public protocol ThrowingInitializable {
    var gate: ThrowingInitializationGate { get }
}

public extension ThrowingInitializable {
    var initialized: Bool {
        get async {
            if case .initialized = await gate.state { return true }
            return false
        }
    }
    
    func markInitialized() async { await gate.markInitialized() }
    
    func markFailed<E: Error>(_ error: E) async { await gate.markFailed(error) }
    
    func awaitInitialized() async throws { try await gate.wait() }
}
