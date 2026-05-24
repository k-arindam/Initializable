// The Swift Programming Language
// https://docs.swift.org/swift-book
//
//  Initializable.swift
//  Initializable
//
//  Public protocols that actors conform to in order to gate method execution
//  behind an asynchronous initialization phase. Each protocol provides
//  default implementations via protocol extensions.
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation

// MARK: - Initializable Protocol

/// A protocol for actors whose methods should suspend until initialization completes.
///
/// Conforming actors must provide a ``gate`` property — an ``InitializationGate`` instance
/// that tracks whether initialization has finished. The protocol provides default
/// implementations for common operations:
///
/// - ``initialized``: An async computed property that returns `true` once the gate is open.
/// - ``markInitialized()``: Opens the gate, resuming all suspended callers.
/// - ``awaitInitialized()``: Suspends until the gate is open.
///
/// ## Conformance
/// ```swift
/// actor MyService: Initializable {
///     let gate = InitializationGate()
///
///     func setup() async {
///         // ... perform async initialization ...
///         await markInitialized()
///     }
///
///     func doWork() async {
///         await awaitInitialized()
///         // ... safe to use initialized state ...
///     }
/// }
/// ```
///
/// ## Macros
/// Use ``AutoAwaitInit()`` to automatically inject `await awaitInitialized()` into
/// all async methods, eliminating manual boilerplate.
///
/// - SeeAlso: ``InitializationGate``, ``ThrowingInitializable``, ``AutoAwaitInit()``
public protocol Initializable {
    /// The initialization gate that controls suspension of callers.
    ///
    /// Conforming types must store this as a `let` constant initialized with
    /// `InitializationGate()`.
    var gate: InitializationGate { get }
}

/// Default implementations for ``Initializable`` conforming types.
public extension Initializable {
    /// Whether the actor has been successfully initialized.
    ///
    /// Returns `true` if ``markInitialized()`` has been called, `false` otherwise.
    ///
    /// - Note: This is an async property because it must access the gate actor's isolated state.
    var initialized: Bool {
        get async {
            if case .initialized = await gate.state { return true }
            return false
        }
    }
    
    /// Opens the initialization gate, resuming all suspended callers.
    ///
    /// This method is **idempotent** — calling it multiple times after the first
    /// invocation has no effect.
    ///
    /// - Important: Call this exactly once after your async setup logic completes.
    func markInitialized() async { await gate.markInitialized() }
    
    /// Suspends the caller until initialization completes.
    ///
    /// If the gate is already open, this returns immediately. Otherwise, the caller
    /// suspends until ``markInitialized()`` is called.
    ///
    /// - Note: Supports cooperative task cancellation. If the waiting task is cancelled,
    ///   the continuation resumes normally (does not throw).
    func awaitInitialized() async { await gate.wait() }
}

// MARK: - ThrowingInitializable Protocol

/// A protocol for actors whose initialization can fail, propagating errors to waiting callers.
///
/// Similar to ``Initializable``, but uses a ``ThrowingInitializationGate`` that supports
/// both success (``markInitialized()``) and failure (``markFailed(_:)``) outcomes.
///
/// Callers of ``awaitInitialized()`` must handle potential errors with `try`.
///
/// ## Conformance
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
///         try await awaitInitialized()
///         // ... execute query ...
///     }
/// }
/// ```
///
/// ## Macros
/// Use ``AutoAwaitThrowingInit()`` to automatically inject `try await awaitInitialized()`
/// into all `async throws` methods.
///
/// - SeeAlso: ``ThrowingInitializationGate``, ``Initializable``, ``AutoAwaitThrowingInit()``
public protocol ThrowingInitializable {
    /// The throwing initialization gate that controls suspension and error propagation.
    ///
    /// Conforming types must store this as a `let` constant initialized with
    /// `ThrowingInitializationGate()`.
    var gate: ThrowingInitializationGate { get }
}

/// Default implementations for ``ThrowingInitializable`` conforming types.
public extension ThrowingInitializable {
    /// Whether the actor has been successfully initialized.
    ///
    /// Returns `true` only if ``markInitialized()`` was called. Returns `false`
    /// if the gate is still pending **or** if ``markFailed(_:)`` was called.
    ///
    /// - Note: This is an async property because it must access the gate actor's isolated state.
    var initialized: Bool {
        get async {
            if case .initialized = await gate.state { return true }
            return false
        }
    }
    
    /// Opens the initialization gate, resuming all suspended callers successfully.
    ///
    /// This method is **idempotent** and respects state stickiness — if ``markFailed(_:)``
    /// was called first, this method is a no-op.
    func markInitialized() async { await gate.markInitialized() }
    
    /// Fails the initialization gate, propagating the error to all suspended callers.
    ///
    /// This method is **idempotent** and respects state stickiness — if ``markInitialized()``
    /// was called first, this method is a no-op. Only the **first** error is stored.
    ///
    /// - Parameter error: The error to propagate to waiting callers.
    func markFailed<E: Error>(_ error: E) async { await gate.markFailed(error) }
    
    /// Suspends the caller until initialization resolves, then returns or throws.
    ///
    /// - If ``markInitialized()`` was called, returns immediately.
    /// - If ``markFailed(_:)`` was called, throws the stored error.
    /// - If still pending, suspends until resolution.
    ///
    /// - Throws: The error passed to ``markFailed(_:)``, or `CancellationError` on task cancellation.
    func awaitInitialized() async throws { try await gate.wait() }
}
