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







//public actor InitializationGate1 {
//    private(set) var state: State = .pending
//    private var continuations = [UUID: CheckedContinuation<Void, any Error>]()
//
//    public init() {}
//
//    fileprivate func markInitialized() {
//        guard case .pending = state else { return }
//        state = .initialized
//        continuations.values.forEach { $0.resume() }
//        continuations.removeAll()
//    }
//
//    fileprivate func markFailed<E: Error>(_ error: E) {
//        guard case .pending = state else { return }
//        state = .failed(error)
//        continuations.values.forEach { $0.resume(throwing: error) }
//        continuations.removeAll()
//    }
//
//    fileprivate func wait() async throws {
//        switch state {
//        case .pending: break
//        case .initialized: return
//        case .failed(let error): throw error
//        }
//
//        let id = UUID()
//        try await withTaskCancellationHandler {
//            try await withCheckedThrowingContinuation(isolation: self) {
//                continuations.updateValue($0, forKey: id)
//            }
//        } onCancel: {
//            Task { await self.cancel(id: id) }
//        }
//    }
//
//    private func cancel(id: UUID) {
//        continuations
//            .removeValue(forKey: id)?
//            .resume(throwing: CancellationError())
//    }
//
//    internal enum State {
//        case pending
//        case initialized
//        case failed(any Error)
//    }
//}
