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
    func markInitialized() async {
        await initializationGate.markInitialized()
    }
    
    func awaitInitialized() async {
        await initializationGate.wait()
    }
}

public actor InitializationGate {
    private var initialized = false
    private var continuations = [CheckedContinuation<Void, Never>]()
    
    public init() {}
    
    fileprivate func markInitialized() {
        guard !initialized else { return }
        initialized = true
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }
    
    fileprivate func wait() async {
        if initialized { return }
        await withCheckedContinuation(isolation: self) {
            continuations.append($0)
        }
    }
}
