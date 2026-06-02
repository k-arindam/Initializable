//
//  Messages.swift
//  InitializableMacros
//
//  Diagnostic and fix-it message types emitted by the Initializable macro suite.
//  All messages conform to `DiagnosticMessage` or `FixItMessage` from SwiftDiagnostics,
//  providing structured error reporting with actionable fix-it suggestions.
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation
import SwiftDiagnostics

// MARK: - WaitForInit Diagnostics

/// Diagnostic messages emitted by ``WaitForInitMacro`` and ``WaitForThrowingInitMacro``.
///
/// These diagnostics cover signature validation (async/throws requirements),
/// conformance checks, and scope validation for the body macros.
///
/// All cases produce `.error` severity diagnostics.
///
/// - SeeAlso: ``WaitForInitFixIt``
enum WaitForInitDiagnostic: DiagnosticMessage {
    /// The function is not `async`.
    ///
    /// Emitted when `@WaitForInit` or `@WaitForThrowingInit` is applied to a synchronous function.
    /// The `throwing` parameter distinguishes between the two macro variants in the message.
    ///
    /// - Parameter throwing: `true` for `@WaitForThrowingInit`, `false` for `@WaitForInit`.
    case notAsync(throwing: Bool)
    
    /// The function is `async` but not `throws`.
    ///
    /// Emitted by `@WaitForThrowingInit` when the function is async but missing `throws`.
    /// This is the most common mistake when migrating from non-throwing to throwing initialization.
    case notThrowing
    
    /// The function is neither `async` nor `throws`.
    ///
    /// Emitted by `@WaitForThrowingInit` when both specifiers are missing.
    case notAsyncThrowing
    
    /// The enclosing type does not conform to the required protocol.
    ///
    /// Emitted when the enclosing type lacks `Initializable` (for `@WaitForInit`)
    /// or `ThrowingInitializable` (for `@WaitForThrowingInit`) conformance.
    ///
    /// - Parameter throwing: `true` for `ThrowingInitializable`, `false` for `Initializable`.
    case notConforming(throwing: Bool)
    
    /// The macro is applied outside of any type declaration (e.g., on a free function).
    ///
    /// Body macros require a lexical enclosing type to verify protocol conformance.
    ///
    /// - Parameter throwing: `true` for `@WaitForThrowingInit`, `false` for `@WaitForInit`.
    case notInType(throwing: Bool)
    
    /// The human-readable diagnostic message string.
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
    
    /// A unique identifier for this diagnostic within the `InitializableMacros` domain.
    var diagnosticID: MessageID {
        MessageID(domain: "InitializableMacros", id: "\(self)")
    }
    
    /// All `WaitForInit` diagnostics are errors — the macro cannot proceed without the fix.
    var severity: DiagnosticSeverity { .error }
}

// MARK: - WaitForInit Fix-Its

/// Fix-it messages that suggest adding missing effect specifiers to function signatures.
///
/// These fix-its accompany ``WaitForInitDiagnostic`` errors and provide one-click
/// code corrections in the IDE.
///
/// - SeeAlso: ``WaitForInitDiagnostic``
enum WaitForInitFixIt: FixItMessage {
    /// Suggests adding the `async` keyword to the function signature.
    case addAsync
    
    /// Suggests adding the `throws` keyword to the function signature.
    case addThrows
    
    /// Suggests adding both `async throws` to the function signature.
    case addAsyncThrows
    
    /// The human-readable fix-it description shown in the IDE.
    var message: String {
        switch self {
        case .addAsync:        "Add 'async'"
        case .addThrows:       "Add 'throws'"
        case .addAsyncThrows:  "Add 'async throws'"
        }
    }
    
    /// A unique identifier for this fix-it within the `InitializableMacros` domain.
    var fixItID: MessageID {
        MessageID(domain: "InitializableMacros", id: "\(self)")
    }
}

// MARK: - AutoAwaitInit Diagnostics

/// Diagnostic messages emitted by ``AutoAwaitInitMacro`` and ``AutoAwaitThrowingInitMacro``.
///
/// These diagnostics cover conformance validation and duplicate attribute detection
/// for the member-attribute macros.
///
/// - SeeAlso: ``AutoAwaitInitFixIt``
enum AutoAwaitInitDiagnostic: DiagnosticMessage {
    /// The type does not conform to the required protocol.
    ///
    /// Emitted when `@AutoAwaitInit` is applied to a type that doesn't conform to
    /// `Initializable`, or `@AutoAwaitThrowingInit` to a type without `ThrowingInitializable`.
    ///
    /// - Parameter throwing: `true` for `@AutoAwaitThrowingInit`, `false` for `@AutoAwaitInit`.
    case notConforming(throwing: Bool)
    
    /// A `@WaitForInit` or `@WaitForThrowingInit` attribute was manually applied to a member
    /// when the enclosing type already has `@AutoAwaitInit` or `@AutoAwaitThrowingInit`.
    ///
    /// This is redundant because the `@AutoAwait*` macro will automatically stamp
    /// the appropriate body macro. The fix-it suggests removing the manual attribute.
    ///
    /// - Parameters:
    ///   - throwing: `true` if the enclosing macro is `@AutoAwaitThrowingInit`.
    ///   - throwingWait: `true` if the duplicate is `@WaitForThrowingInit`, `false` for `@WaitForInit`.
    case manualWaitForInit(throwing: Bool, throwingWait: Bool)
    
    /// The human-readable diagnostic message string.
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
    
    /// A unique identifier for this diagnostic within the `InitializableMacros` domain.
    var diagnosticID: MessageID {
        MessageID(domain: "InitializableMacros", id: "\(self)")
    }
    
    /// All `AutoAwaitInit` diagnostics are errors.
    var severity: DiagnosticSeverity { .error }
}

// MARK: - AutoAwaitInit Fix-Its

/// Fix-it messages for removing redundant manual `@WaitForInit`/`@WaitForThrowingInit` attributes.
///
/// Accompanies ``AutoAwaitInitDiagnostic/manualWaitForInit(throwing:throwingWait:)``
/// to provide a one-click removal of the duplicate attribute.
///
/// - SeeAlso: ``AutoAwaitInitDiagnostic``
enum AutoAwaitInitFixIt: FixItMessage {
    /// Suggests removing the manually-applied `@WaitForInit` or `@WaitForThrowingInit`.
    ///
    /// - Parameter throwingWait: `true` to remove `@WaitForThrowingInit`, `false` for `@WaitForInit`.
    case removeWaitForInit(throwingWait: Bool)
    
    /// The human-readable fix-it description shown in the IDE.
    var message: String {
        switch self {
        case .removeWaitForInit(let throwingWait):
            let component = throwingWait ? "@WaitForThrowingInit" : "@WaitForInit"
            return "Remove \(component)"
        }
    }
    
    /// A unique identifier for this fix-it within the `InitializableMacros` domain.
    var fixItID: MessageID {
        MessageID(domain: "InitializableMacros", id: "\(self)")
    }
}

// MARK: - SkipInit Diagnostics

/// Diagnostic messages emitted by ``SkipInitMacro``.
///
/// These diagnostics validate that `@SkipInit` is applied in a meaningful context —
/// specifically, on an `async` function inside a type that uses `@AutoAwaitInit`
/// or `@AutoAwaitThrowingInit`.
///
/// All cases produce `.error` severity diagnostics with an accompanying
/// ``SkipInitFixIt/removeSkipInit`` fix-it.
///
/// - SeeAlso: ``SkipInitFixIt``, ``SkipInitMacro``
enum SkipInitDiagnostic: DiagnosticMessage {
    /// The enclosing type does not have `@AutoAwaitInit` or `@AutoAwaitThrowingInit`.
    ///
    /// Emitted when `@SkipInit` is applied to a method inside a type (or at the top level)
    /// that has no automatic stamping macro. Since there is no automatic `@WaitForInit`
    /// to opt out of, the annotation is meaningless and should be removed.
    case notInsideAutoAwaitInit

    /// The function is not `async`.
    ///
    /// Emitted when `@SkipInit` is applied to a synchronous function. Synchronous methods
    /// are never stamped by `@AutoAwaitInit` or `@AutoAwaitThrowingInit`, so `@SkipInit`
    /// is redundant and likely a mistake.
    case notAsync
    
    /// The human-readable diagnostic message string.
    var message: String {
        switch self {
        case .notInsideAutoAwaitInit:
            "@SkipInit can only be used inside a type marked with @AutoAwaitInit or @AutoAwaitThrowingInit"
        case .notAsync:
            "@SkipInit can only be applied to async functions, sync functions are never wrapped"
        }
    }
    
    /// A unique identifier for this diagnostic within the `InitializableMacros` domain.
    var diagnosticID: MessageID {
        MessageID(domain: "InitializableMacros", id: "\(self)")
    }
    
    /// All `SkipInit` diagnostics are errors — the attribute is invalid and should be removed.
    var severity: DiagnosticSeverity { .error }
}

// MARK: - SkipInit Fix-Its

/// Fix-it messages that suggest removing an invalid `@SkipInit` attribute.
///
/// Accompanies ``SkipInitDiagnostic`` errors to provide a one-click removal of
/// the misplaced `@SkipInit` annotation in the IDE.
///
/// - SeeAlso: ``SkipInitDiagnostic``
enum SkipInitFixIt: FixItMessage {
    /// Suggests removing the `@SkipInit` attribute from the function declaration.
    case removeSkipInit
    
    /// The human-readable fix-it description shown in the IDE.
    var message: String { "Remove '@SkipInit'" }
    
    /// A unique identifier for this fix-it within the `InitializableMacros` domain.
    var fixItID: MessageID {
        MessageID(domain: "InitializableMacros", id: "\(self)")
    }
}
