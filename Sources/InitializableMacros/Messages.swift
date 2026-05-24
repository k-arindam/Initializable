//
//  Messages.swift
//  InitializableMacros
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation
import SwiftDiagnostics

enum WaitForInitDiagnostic: DiagnosticMessage {
    case notAsync
    case notThrowing
    case notAsyncThrowing
    
    var message: String {
        switch self {
        case .notAsync:
            "@WaitForInit requires the function to be 'async'"
        case .notThrowing:
            "@WaitForInit requires the function to be 'throws' because awaitInitialized() can throw"
        case .notAsyncThrowing:
            "@WaitForInit requires the function to be 'async throws'"
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
