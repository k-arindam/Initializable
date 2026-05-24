//
//  Gate.swift
//  Initializable
//
//  Core concurrency primitives that gate access to actor methods until
//  asynchronous initialization completes. Built on `CheckedContinuation`
//  with task-cancellation support.
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation

// MARK: - InitializationGateBase Protocol

/// A protocol that defines the shared state and behavior for initialization gates.
///
/// Both ``InitializationGate`` and ``ThrowingInitializationGate`` conform to this protocol,
/// sharing the `markInitialized()` and `cancel(id:)` implementations via a protocol extension.
///
/// ## Thread Safety
/// Conforming types must be `Actor`s, ensuring all mutable state (`state`, `continuations`)
/// is accessed serially within the actor's isolation domain.
///
/// ## Associated Types
/// - `ContinuationError`: `Never` for non-throwing gates, `any Error` for throwing gates.
///
/// - SeeAlso: ``InitializationGate``, ``ThrowingInitializationGate``
internal protocol InitializationGateBase: Actor {
    /// The error type used by the gate's checked continuations.
    associatedtype ContinuationError: Error
    
    /// Determines cancellation behavior: `.throwable` or `.nonThrowable`.
    var type: GateType { get }

    /// The current lifecycle state of the gate.
    var state: InitializationState { get set }

    /// Registered continuations keyed by a unique `UUID`, resumed when the gate opens or fails.
    var continuations: [UUID: CheckedContinuation<Void, ContinuationError>] { get set }
}

// MARK: - InitializationGateBase Default Implementations

/// Default implementations shared between ``InitializationGate`` and ``ThrowingInitializationGate``.
internal extension InitializationGateBase {
    /// Transitions the gate from ``InitializationState/pending`` to ``InitializationState/initialized``,
    /// resuming all suspended continuations.
    ///
    /// If the gate has already transitioned (to either `.initialized` or `.failed`), this method
    /// is a **no-op**, ensuring idempotent behavior.
    ///
    /// - Important: This method must be called from within the actor's isolation context.
    func markInitialized() {
        guard case .pending = state else { return }
        state = .initialized
        continuations.values.forEach { $0.resume() }
        continuations.removeAll()
    }
    
    /// Handles task cancellation for a specific waiting continuation.
    ///
    /// Behavior depends on the gate's ``GateType``:
    /// - **Non-throwable** (``InitializationGate``): Resumes the continuation normally.
    /// - **Throwable** (``ThrowingInitializationGate``): Resumes by throwing `CancellationError`.
    ///
    /// - Parameter id: The unique identifier of the continuation to cancel.
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

// MARK: - InitializationGate (Non-Throwing)

/// A non-throwing initialization gate that suspends callers until the gate is opened.
///
/// Use `InitializationGate` when your actor's initialization cannot fail. Callers of
/// ``wait()`` will suspend until ``markInitialized()`` is called, after which all
/// current and future callers proceed immediately.
///
/// ## Usage
/// Typically consumed via the ``Initializable`` protocol, which provides convenience
/// methods (`awaitInitialized()`, `markInitialized()`) that delegate to this gate.
///
/// ```swift
/// actor MyService: Initializable {
///     let gate = InitializationGate()
///
///     func setup() async {
///         // ... perform async setup ...
///         await markInitialized()
///     }
///
///     func doWork() async {
///         await awaitInitialized()  // suspends until setup() completes
///         // ... safe to proceed ...
///     }
/// }
/// ```
///
/// ## Cancellation
/// If a waiting task is cancelled, the continuation resumes **normally** (returns `Void`)
/// rather than throwing, since the continuation error type is `Never`.
///
/// - SeeAlso: ``Initializable``, ``ThrowingInitializationGate``
public actor InitializationGate: InitializationGateBase {
    /// The cancellation behavior for this gate: always `.nonThrowable`.
    internal let type: GateType = .nonThrowable

    /// The current lifecycle state, starting at `.pending`.
    internal var state: InitializationState = .pending

    /// Registered continuations waiting for the gate to open, keyed by `UUID`.
    internal var continuations = [UUID : CheckedContinuation<Void, Never>]()
    
    /// Creates a new initialization gate in the ``InitializationState/pending`` state.
    public init() {}
    
    /// Suspends the caller until the gate transitions out of ``InitializationState/pending``.
    ///
    /// - If the gate is already `.initialized` (or `.failed`), returns immediately.
    /// - If the gate is `.pending`, registers a `CheckedContinuation` and suspends.
    /// - Supports cooperative task cancellation via `withTaskCancellationHandler`.
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

// MARK: - ThrowingInitializationGate

/// A throwing initialization gate that supports both success and failure outcomes.
///
/// Use `ThrowingInitializationGate` when your actor's initialization can fail.
/// Callers of ``wait()`` will either:
/// - Resume successfully after ``markInitialized()``
/// - Throw the stored error after ``markFailed(_:)``
///
/// ## Usage
/// Typically consumed via the ``ThrowingInitializable`` protocol.
///
/// ```swift
/// actor DatabaseService: ThrowingInitializable {
///     let gate = ThrowingInitializationGate()
///
///     func connect() async {
///         do {
///             try await establishConnection()
///             await markInitialized()
///         } catch {
///             await markFailed(error)
///         }
///     }
///
///     func query(_ sql: String) async throws -> [Row] {
///         try await awaitInitialized()  // throws if connect() failed
///         // ... execute query ...
///     }
/// }
/// ```
///
/// ## State Stickiness
/// The first call to either `markInitialized()` or `markFailed(_:)` wins.
/// Subsequent calls to either method are no-ops.
///
/// ## Cancellation
/// If a waiting task is cancelled, the continuation throws `CancellationError`.
///
/// - SeeAlso: ``ThrowingInitializable``, ``InitializationGate``
public actor ThrowingInitializationGate: InitializationGateBase {
    /// The cancellation behavior for this gate: always `.throwable`.
    internal let type: GateType = .throwable

    /// The current lifecycle state, starting at `.pending`.
    internal var state: InitializationState = .pending

    /// Registered continuations waiting for the gate to resolve, keyed by `UUID`.
    internal var continuations = [UUID : CheckedContinuation<Void, any Error>]()
    
    /// Creates a new throwing initialization gate in the ``InitializationState/pending`` state.
    public init() {}
    
    /// Transitions the gate from ``InitializationState/pending`` to ``InitializationState/failed(_:)``,
    /// resuming all suspended continuations by throwing the provided error.
    ///
    /// If the gate has already transitioned, this method is a **no-op**.
    ///
    /// - Parameter error: The error to propagate to all waiting callers.
    internal func markFailed<E: Error>(_ error: E) {
        guard case .pending = state else { return }
        state = .failed(error)
        continuations.values.forEach { $0.resume(throwing: error) }
        continuations.removeAll()
    }
    
    /// Suspends the caller until the gate resolves, then either returns or throws.
    ///
    /// - If the gate is `.initialized`, returns immediately.
    /// - If the gate is `.failed`, throws the stored error immediately.
    /// - If the gate is `.pending`, registers a `CheckedContinuation` and suspends.
    /// - Supports cooperative task cancellation via `withTaskCancellationHandler`.
    ///
    /// - Throws: The error stored by ``markFailed(_:)``, or `CancellationError` on task cancellation.
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
