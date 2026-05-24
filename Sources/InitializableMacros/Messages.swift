//
//  Messages.swift
//  InitializableMacros
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation
import SwiftDiagnostics

enum WaitForInitDiagnostic: DiagnosticMessage {
    case notAsync(throwing: Bool)
    case notThrowing
    case notAsyncThrowing
    case notConforming(throwing: Bool)
    case notInType(throwing: Bool)
    
    var message: String {
        switch self {
        case .notAsync(let throwing):
            let leading = throwing ? "@WaitForThrowingInit" : "@WaitForInit"
            return "\(leading) requires the function to be 'async'"
        case .notThrowing:
            return "@WaitForThrowingInit requires the function to be 'throws' because awaitInitialized() can throw"
        case .notAsyncThrowing:
            return "@WaitForThrowingInit requires the function to be 'async throws'"
        case .notConforming(let throwing):
            let leading = throwing ? "@WaitForThrowingInit" : "@WaitForInit"
            let trailing = throwing ? "'ThrowingInitializable'" : "'Initializable'"
            return "\(leading) can only be used in a type that conforms to \(trailing)"
        case .notInType(let throwing):
            let leading = throwing ? "@WaitForThrowingInit" : "@WaitForInit"
            return "\(leading) can only be applied inside a type declaration"
        }
    }
    
    var diagnosticID: MessageID {
        MessageID(domain: "InitializableMacros", id: "\(self)")
    }
    
    var severity: DiagnosticSeverity { .error }
}

enum WaitForInitFixIt: FixItMessage {
    case addAsync
    case addThrows
    case addAsyncThrows
    
    var message: String {
        switch self {
        case .addAsync:        "Add 'async'"
        case .addThrows:       "Add 'throws'"
        case .addAsyncThrows:  "Add 'async throws'"
        }
    }
    
    var fixItID: MessageID {
        MessageID(domain: "InitializableMacros", id: "\(self)")
    }
}

enum AutoAwaitInitDiagnostic: DiagnosticMessage {
    case notConforming(throwing: Bool)
    case manualWaitForInit(throwing: Bool, throwingWait: Bool)
    
    var message: String {
        switch self {
        case .notConforming(let throwing):
            let leading = throwing ? "@AutoAwaitThrowingInit" : "@AutoAwaitInit"
            let trailing = throwing ? "'ThrowingInitializable'" : "'Initializable'"
            return "\(leading) can only be applied to a type that conforms to \(trailing)"
        case let .manualWaitForInit(throwing, throwingWait):
            let leading = throwingWait ? "@WaitForThrowingInit" : "@WaitForInit"
            let trailing = throwing ? "@AutoAwaitThrowingInit" : "@AutoAwaitInit"
            return "\(leading) should not be added manually when \(trailing) is applied to the enclosing type"
        }
    }
    
    var diagnosticID: MessageID {
        MessageID(domain: "InitializableMacros", id: "\(self)")
    }
    
    var severity: DiagnosticSeverity { .error }
}

enum AutoAwaitInitFixIt: FixItMessage {
    case removeWaitForInit(throwingWait: Bool)
    
    var message: String {
        switch self {
        case .removeWaitForInit(let throwingWait):
            let component = throwingWait ? "@WaitForThrowingInit" : "@WaitForInit"
            return "Remove \(component)"
        }
    }
    
    var fixItID: MessageID {
        MessageID(domain: "InitializableMacros", id: "\(self)")
    }
}
