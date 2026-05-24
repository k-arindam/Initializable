//
//  Gate.swift
//  Initializable
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation

internal protocol InitializationGateBase: Actor {
    associatedtype ContinuationError: Error
    
    var type: GateType { get }
    var state: InitializationState { get set }
    var continuations: [UUID: CheckedContinuation<Void, ContinuationError>] { get set }
}

internal extension InitializationGateBase {
    func markInitialized() {
        guard case .pending = state else { return }
        state = .initialized
        continuations.values.forEach { $0.resume() }
        continuations.removeAll()
    }
    
    func cancel(id: UUID) {
        let cont = continuations.removeValue(forKey: id)
        switch type {
        case .nonThrowable: cont?.resume()
        case .throwable:
            if let error = CancellationError() as? ContinuationError {
                cont?.resume(throwing: error)
            } else { cont?.resume() }
        }
    }
}

public actor InitializationGate: InitializationGateBase {
    internal let type: GateType = .nonThrowable
    internal var state: InitializationState = .pending
    internal var continuations = [UUID : CheckedContinuation<Void, Never>]()
    
    public init() {}
    
    internal func wait() async {
        switch state {
        case .pending: break
        default: return
        }
        
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation(isolation: self) {
                continuations.updateValue($0, forKey: id)
            }
        } onCancel: {
            Task { await self.cancel(id: id) }
        }
    }
}

public actor ThrowingInitializationGate: InitializationGateBase {
    internal let type: GateType = .throwable
    internal var state: InitializationState = .pending
    internal var continuations = [UUID : CheckedContinuation<Void, any Error>]()
    
    public init() {}
    
    internal func markFailed<E: Error>(_ error: E) {
        guard case .pending = state else { return }
        state = .failed(error)
        continuations.values.forEach { $0.resume(throwing: error) }
        continuations.removeAll()
    }
    
    internal func wait() async throws {
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
}
