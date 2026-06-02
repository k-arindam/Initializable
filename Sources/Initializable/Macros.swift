//
//  Macros.swift
//  Initializable
//
//  Public macro declarations that bridge to the compiler plugin implementations
//  in the `InitializableMacros` module. These macros automate the injection of
//  initialization-gating calls into actor methods at compile time.
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation

// MARK: - Member Attribute Macros

/// Automatically stamps `@WaitForInit` on every `async` method in the conforming type.
///
/// Apply this macro to an actor (or class/struct) that conforms to ``Initializable``.
/// During compilation, the macro inspects each method member and attaches `@WaitForInit`
/// to those that are `async`, ensuring they suspend until initialization completes.
///
/// ## Behavior
/// - **Stamps**: All `async` (and `async throws`) methods receive `@WaitForInit`.
/// - **Excludes**: `markInitialized()` and `awaitInitialized()` (protocol methods).
/// - **Skips**: Non-function members (properties, initializers, subscripts) and sync methods.
/// - **Diagnoses**: Emits an error if the type doesn't conform to `Initializable`.
/// - **Detects duplicates**: Emits an error with a fix-it if a method already has
///   `@WaitForInit` or `@WaitForThrowingInit` applied manually.
///
/// ## Example
/// ```swift
/// @AutoAwaitInit
/// actor MyService: Initializable {
///     let gate = InitializationGate()
///
///     // ✅ Gets @WaitForInit stamped automatically
///     func fetchData() async -> Data { ... }
///
///     // ❌ Sync — skipped
///     func helper() -> String { ... }
/// }
/// ```
///
/// - SeeAlso: ``WaitForInit()``, ``AutoAwaitThrowingInit()``, ``Initializable``
@attached(memberAttribute)
public macro AutoAwaitInit() = #externalMacro(
    module: "InitializableMacros",
    type: "AutoAwaitInitMacro"
)

/// Automatically stamps `@WaitForThrowingInit` on every `async throws` method in the conforming type.
///
/// Apply this macro to an actor (or class/struct) that conforms to ``ThrowingInitializable``.
/// During compilation, the macro inspects each method member and attaches `@WaitForThrowingInit`
/// to those that are `async throws`.
///
/// ## Behavior
/// - **Stamps**: Only `async throws` methods receive `@WaitForThrowingInit`.
/// - **Excludes**: `markInitialized()`, `markFailed()`, and `awaitInitialized()`.
/// - **Diagnoses**: `async`-only methods (missing `throws`) receive a warning with a fix-it.
/// - **Skips**: Sync methods, `throws`-only methods, and non-function members.
/// - **Detects duplicates**: Emits an error if `@WaitForInit` or `@WaitForThrowingInit` is already present.
///
/// ## Example
/// ```swift
/// @AutoAwaitThrowingInit
/// actor DatabaseService: ThrowingInitializable {
///     let gate = ThrowingInitializationGate()
///
///     // ✅ Gets @WaitForThrowingInit — async throws
///     func query(_ sql: String) async throws -> [Row] { ... }
///
///     // ⚠️ Diagnostic: async but not throws — suggests adding throws
///     func ping() async -> Bool { ... }
/// }
/// ```
///
/// - SeeAlso: ``WaitForThrowingInit()``, ``AutoAwaitInit()``, ``ThrowingInitializable``
@attached(memberAttribute)
public macro AutoAwaitThrowingInit() = #externalMacro(
    module: "InitializableMacros",
    type: "AutoAwaitThrowingInitMacro"
)

// MARK: - Body Macros

/// Prepends `await awaitInitialized()` to the decorated function's body.
///
/// Apply this macro to individual `async` methods in a type conforming to ``Initializable``.
/// At compile time, the macro injects a suspension point at the very beginning of the
/// function body, ensuring the method waits for initialization before executing.
///
/// ## Generated Code
/// ```swift
/// // Before expansion:
/// @WaitForInit
/// func fetchData() async -> String {
///     return "data"
/// }
///
/// // After expansion:
/// func fetchData() async -> String {
///     await awaitInitialized()  // ← injected
///     return "data"
/// }
/// ```
///
/// ## Diagnostics
/// - **Not async**: Emits an error with a fix-it to add `async`.
/// - **Not in type**: Emits an error if applied to a free function.
/// - **Not conforming**: Emits an error if the enclosing type doesn't conform to `Initializable`.
///
/// - Note: Prefer ``AutoAwaitInit()`` to apply this automatically to all async methods.
/// - SeeAlso: ``AutoAwaitInit()``, ``WaitForThrowingInit()``
@attached(body)
public macro WaitForInit() = #externalMacro(
    module: "InitializableMacros",
    type: "WaitForInitMacro"
)

/// Prepends `try await awaitInitialized()` to the decorated function's body.
///
/// Apply this macro to individual `async throws` methods in a type conforming
/// to ``ThrowingInitializable``. At compile time, the macro injects a throwing
/// suspension point at the very beginning of the function body.
///
/// ## Generated Code
/// ```swift
/// // Before expansion:
/// @WaitForThrowingInit
/// func query() async throws -> [Row] {
///     return try await db.execute(sql)
/// }
///
/// // After expansion:
/// func query() async throws -> [Row] {
///     try await awaitInitialized()  // ← injected
///     return try await db.execute(sql)
/// }
/// ```
///
/// ## Diagnostics
/// - **Not async throws**: Emits an error with a fix-it to add `async throws`.
/// - **Not async**: Emits an error with a fix-it to add `async` (when only `throws`).
/// - **Not throwing**: Emits an error with a fix-it to add `throws` (when only `async`).
/// - **Not in type**: Emits an error if applied to a free function.
/// - **Not conforming**: Emits an error if the type doesn't conform to `ThrowingInitializable`.
///
/// - Note: Prefer ``AutoAwaitThrowingInit()`` to apply this automatically to all `async throws` methods.
/// - SeeAlso: ``AutoAwaitThrowingInit()``, ``WaitForInit()``
@attached(body)
public macro WaitForThrowingInit() = #externalMacro(
    module: "InitializableMacros",
    type: "WaitForThrowingInitMacro"
)

/// Opts an individual `async` method out of automatic initialization gating.
///
/// Apply this macro to a specific method inside a type that uses ``AutoAwaitInit()``
/// or ``AutoAwaitThrowingInit()`` to prevent the enclosing member-attribute macro from
/// stamping `@WaitForInit` or `@WaitForThrowingInit` on that method. The method will
/// execute immediately without waiting for the initialization gate to open.
///
/// ## When to Use
/// Use `@SkipInit` for methods that must be callable before initialization completes,
/// such as the initialization routine itself, cancellation handlers, or introspection helpers.
///
/// ## Example
/// ```swift
/// @AutoAwaitInit
/// actor MyService: Initializable {
///     let gate = InitializationGate()
///
///     // ✅ Skipped — this IS the initialization method
///     @SkipInit
///     func setup() async {
///         await loadResources()
///         await markInitialized()
///     }
///
///     // ✅ Gets @WaitForInit automatically
///     func fetchData() async -> Data { ... }
/// }
/// ```
///
/// ## Diagnostics
/// - **Not async**: Emits an error with a fix-it to remove `@SkipInit`, because
///   synchronous methods are never stamped by `@AutoAwaitInit`/`@AutoAwaitThrowingInit`
///   in the first place — the annotation is redundant.
/// - **No enclosing `@AutoAwaitInit`/`@AutoAwaitThrowingInit`**: Emits an error with
///   a fix-it to remove `@SkipInit`, since there is nothing to skip.
///
/// - Note: This macro produces no peer declarations. It acts purely as a marker
///   that is checked by the ``AutoAwaitInit()`` and ``AutoAwaitThrowingInit()`` macros.
/// - SeeAlso: ``AutoAwaitInit()``, ``AutoAwaitThrowingInit()``, ``WaitForInit()``
@attached(peer)
public macro SkipInit() = #externalMacro(
    module: "InitializableMacros",
    type: "SkipInitMacro"
)
