//
//  Enums.swift
//  Initializable
//
//  Internal enumeration types that represent the lifecycle state of an
//  initialization gate and the error-handling behavior of its continuations.
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation

/// Represents the current lifecycle state of an ``InitializationGate`` or
/// ``ThrowingInitializationGate``.
///
/// The state machine follows a one-way progression:
/// - Starts at ``pending``
/// - Transitions to either ``initialized`` or ``failed(_:)``
/// - Once transitioned, the state is **sticky** — further mutations are no-ops.
///
/// - SeeAlso: ``InitializationGateBase``
internal enum InitializationState {
    /// The gate has not yet been resolved. Callers of `wait()` will suspend.
    case pending

    /// The gate has been successfully opened. All suspended and future callers proceed immediately.
    case initialized

    /// The gate has been permanently failed with the associated error.
    ///
    /// Only applicable to ``ThrowingInitializationGate``. Suspended and future callers
    /// receive this error when they attempt to `wait()`.
    ///
    /// - Parameter error: The error that caused initialization to fail.
    case failed(any Error)
}

/// Determines how a gate's continuations behave when a waiting task is cancelled.
///
/// - ``nonThrowable``: The continuation resumes normally (returns `Void`).
///   Used by ``InitializationGate`` whose continuation error type is `Never`.
/// - ``throwable``: The continuation resumes by throwing a `CancellationError`.
///   Used by ``ThrowingInitializationGate`` whose continuation error type is `any Error`.
///
/// - SeeAlso: ``InitializationGateBase/cancel(id:)``
internal enum GateType {
    /// Cancellation resumes the continuation by throwing `CancellationError`.
    case throwable

    /// Cancellation resumes the continuation normally without throwing.
    case nonThrowable
}
