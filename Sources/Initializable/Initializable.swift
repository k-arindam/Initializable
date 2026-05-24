// The Swift Programming Language
// https://docs.swift.org/swift-book
//
//  Initializable.swift
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation

public protocol Initializable {
    var initializationGate: InitializationGate { get }
}

public extension Initializable {
    var initialized: Bool {
        get async {
            if case .initialized = await initializationGate.state { return true }
            return false
        }
    }
    
    func markInitialized() async {
        await initializationGate.markInitialized()
    }
    
    func markFailed<E: Error>(_ error: E) async {
        await initializationGate.markFailed(error)
    }
    
    func awaitInitialized() async throws {
        try await initializationGate.wait()
    }
}

public actor InitializationGate {
    private(set) var state: State = .pending
    private var continuations = [UUID: CheckedContinuation<Void, any Error>]()
    
    public init() {}
    
    fileprivate func markInitialized() {
        guard case .pending = state else { return }
        state = .initialized
        continuations.values.forEach { $0.resume() }
        continuations.removeAll()
    }
    
    fileprivate func markFailed<E: Error>(_ error: E) {
        guard case .pending = state else { return }
        state = .failed(error)
        continuations.values.forEach { $0.resume(throwing: error) }
        continuations.removeAll()
    }
    
    fileprivate func wait() async throws {
        switch state {
        case .pending: break
        case .initialized: return
        case .failed(let error): throw error
        }
        
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation(isolation: self) {
                continuations.updateValue($0, forKey: id)
            }
        } onCancel: {
            Task { await self.cancel(id: id) }
        }
    }
    
    private func cancel(id: UUID) {
        continuations
            .removeValue(forKey: id)?
            .resume(throwing: CancellationError())
    }
    
    internal enum State {
        case pending
        case initialized
        case failed(any Error)
    }
}
