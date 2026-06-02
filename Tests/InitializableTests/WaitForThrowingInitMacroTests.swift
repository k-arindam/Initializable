//
//  WaitForThrowingInitMacroTests.swift
//  InitializableTests
//
//  Tests for the `@WaitForThrowingInit` body macro.
//
//  Validates that the macro correctly injects `try await awaitInitialized()` at the
//  start of `async throws` function bodies, and emits appropriate diagnostics for
//  all four async/throws combinations when the signature is incorrect.
//
//  Uses `assertMacroExpansion` from `SwiftSyntaxMacrosTestSupport` to verify
//  compile-time AST transformations without running the generated code.
//

import Testing
import SwiftSyntaxMacrosTestSupport

#if canImport(InitializableMacros)
@testable import InitializableMacros

// MARK: - @WaitForThrowingInit Body Macro Tests

/// Test suite for the `@WaitForThrowingInit` body macro.
///
/// Covers three categories:
/// - **Happy path**: Verifies correct `try await awaitInitialized()` injection.
/// - **Edge cases**: Empty bodies, complex signatures, body preservation on error paths.
/// - **Diagnostics**: All four async/throws permutations, conformance checks, and scope validation.
///
/// - SeeAlso: ``WaitForThrowingInitMacro``
@Suite("@WaitForThrowingInit Macro")
struct WaitForThrowingInitMacroTests {

    // MARK: - Happy Path: Code Injection (async throws)

    /// Verifies that `try await awaitInitialized()` is prepended to an `async throws` function.
    /// This is the throwing variant — note `try await` instead of just `await`.
    @Test("Prepends 'try await awaitInitialized()' to async throws function body")
    func prependsTryAwaitInitialized() {
        assertMacroExpansion(
            """
            actor Svc: ThrowingInitializable {
                @WaitForThrowingInit
                func fetchData() async throws -> String {
                    return "data"
                }
            }
            """,
            expandedSource: """
            actor Svc: ThrowingInitializable {
                func fetchData() async throws -> String {
                    try await awaitInitialized()
                    return "data"
                }
            }
            """,
            macros: ["WaitForThrowingInit": WaitForThrowingInitMacro.self]
        )
    }

    /// Verifies that all original statements are preserved after the injected `try await` call.
    @Test("Preserves multi-statement body")
    func preservesMultiStatementBody() {
        assertMacroExpansion(
            """
            actor Svc: ThrowingInitializable {
                @WaitForThrowingInit
                func process(_ id: Int) async throws {
                    let value = id * 2
                    print(value)
                }
            }
            """,
            expandedSource: """
            actor Svc: ThrowingInitializable {
                func process(_ id: Int) async throws {
                    try await awaitInitialized()
                    let value = id * 2
                    print(value)
                }
            }
            """,
            macros: ["WaitForThrowingInit": WaitForThrowingInitMacro.self]
        )
    }

    /// Verifies that an `async throws` function with an empty body receives the injection.
    @Test("Handles empty body async throws function")
    func emptyBodyAsyncThrowsFunction() {
        assertMacroExpansion(
            """
            actor Svc: ThrowingInitializable {
                @WaitForThrowingInit
                func noOp() async throws {
                }
            }
            """,
            expandedSource: """
            actor Svc: ThrowingInitializable {
                func noOp() async throws {
                    try await awaitInitialized()
                }
            }
            """,
            macros: ["WaitForThrowingInit": WaitForThrowingInitMacro.self]
        )
    }

    /// Verifies correct expansion with complex parameter lists and named tuple return types.
    @Test("Complex signature with multiple params and tuple return")
    func complexSignature() {
        assertMacroExpansion(
            """
            actor Svc: ThrowingInitializable {
                @WaitForThrowingInit
                func process(_ data: [String], count: Int) async throws -> (success: Bool, message: String) {
                    return (true, "ok")
                }
            }
            """,
            expandedSource: """
            actor Svc: ThrowingInitializable {
                func process(_ data: [String], count: Int) async throws -> (success: Bool, message: String) {
                    try await awaitInitialized()
                    return (true, "ok")
                }
            }
            """,
            macros: ["WaitForThrowingInit": WaitForThrowingInitMacro.self]
        )
    }

    /// Verifies that guard and control flow statements are preserved after injection.
    @Test("Preserves guard and control flow in body")
    func preservesGuardAndControlFlow() {
        assertMacroExpansion(
            """
            actor Svc: ThrowingInitializable {
                @WaitForThrowingInit
                func validate(_ input: String?) async throws -> Bool {
                    guard let input else { return false }
                    return !input.isEmpty
                }
            }
            """,
            expandedSource: """
            actor Svc: ThrowingInitializable {
                func validate(_ input: String?) async throws -> Bool {
                    try await awaitInitialized()
                    guard let input else { return false }
                    return !input.isEmpty
                }
            }
            """,
            macros: ["WaitForThrowingInit": WaitForThrowingInitMacro.self]
        )
    }

    // MARK: - Diagnostics: Not Async Throws (sync, non-throwing)

    /// Verifies that a synchronous, non-throwing function gets the "not async throws" diagnostic
    /// with a fix-it to add both `async throws`.
    @Test("Diagnoses sync non-throwing function — emits 'not async throws' with fix-it")
    func diagnosticNotAsyncThrowing() {
        assertMacroExpansion(
            """
            actor Svc: ThrowingInitializable {
                @WaitForThrowingInit
                func setup() {
                    print("setup")
                }
            }
            """,
            expandedSource: """
            actor Svc: ThrowingInitializable {
                func setup() {
                    print("setup")
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForThrowingInit requires the function to be 'async throws'",
                    line: 2,
                    column: 5,
                    fixIts: [FixItSpec(message: "Add 'async throws'")]
                )
            ],
            macros: ["WaitForThrowingInit": WaitForThrowingInitMacro.self]
        )
    }

    // MARK: - Diagnostics: Throws but Not Async

    /// Verifies that a `throws`-only function gets the "not async" diagnostic
    /// with a fix-it to add `async`.
    @Test("Diagnoses throws-only function — emits 'not async' with fix-it")
    func diagnosticNotAsync() {
        assertMacroExpansion(
            """
            actor Svc: ThrowingInitializable {
                @WaitForThrowingInit
                func riskyOp() throws -> Int {
                    return 42
                }
            }
            """,
            expandedSource: """
            actor Svc: ThrowingInitializable {
                func riskyOp() throws -> Int {
                    return 42
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForThrowingInit requires the function to be 'async'",
                    line: 2,
                    column: 5,
                    fixIts: [FixItSpec(message: "Add 'async'")]
                )
            ],
            macros: ["WaitForThrowingInit": WaitForThrowingInitMacro.self]
        )
    }

    // MARK: - Diagnostics: Async but Not Throwing

    /// Verifies that an `async`-only function gets the "not throwing" diagnostic
    /// with a fix-it to add `throws`. This is the most common mistake when migrating.
    @Test("Diagnoses async-only function — emits 'not throwing' with fix-it")
    func diagnosticNotThrowing() {
        assertMacroExpansion(
            """
            actor Svc: ThrowingInitializable {
                @WaitForThrowingInit
                func fetchData() async -> String {
                    return "data"
                }
            }
            """,
            expandedSource: """
            actor Svc: ThrowingInitializable {
                func fetchData() async -> String {
                    return "data"
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForThrowingInit requires the function to be 'throws' because awaitInitialized() can throw",
                    line: 2,
                    column: 5,
                    fixIts: [FixItSpec(message: "Add 'throws'")]
                )
            ],
            macros: ["WaitForThrowingInit": WaitForThrowingInitMacro.self]
        )
    }

    // MARK: - Diagnostics: Not Conforming

    /// Verifies the "not conforming" error when the type lacks `ThrowingInitializable`.
    @Test("Diagnoses when type does not conform to ThrowingInitializable")
    func diagnosticNotConforming() {
        assertMacroExpansion(
            """
            actor Svc {
                @WaitForThrowingInit
                func fetchData() async throws -> String {
                    return "data"
                }
            }
            """,
            expandedSource: """
            actor Svc {
                func fetchData() async throws -> String {
                    return "data"
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForThrowingInit can only be used in a type that conforms to 'ThrowingInitializable'",
                    line: 2,
                    column: 5
                )
            ],
            macros: ["WaitForThrowingInit": WaitForThrowingInitMacro.self]
        )
    }

    // MARK: - Diagnostics: Not In Type

    /// Verifies the "not in type" error when `@WaitForThrowingInit` is applied to a free function.
    @Test("Diagnoses when applied at free-function scope")
    func diagnosticNotInType() {
        assertMacroExpansion(
            """
            @WaitForThrowingInit
            func freeFunction() async throws {
                print("hello")
            }
            """,
            expandedSource: """
            func freeFunction() async throws {
                print("hello")
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForThrowingInit can only be applied inside a type declaration",
                    line: 1,
                    column: 1
                )
            ],
            macros: ["WaitForThrowingInit": WaitForThrowingInitMacro.self]
        )
    }

    // MARK: - Edge: Returns Original Body on Error

    /// Verifies that the original function body is returned **unchanged** when the macro
    /// emits a diagnostic, ensuring the code remains valid even without the injection.
    @Test("Returns original body unchanged when diagnostic is emitted for sync function")
    func preservesBodyOnSyncDiagnostic() {
        assertMacroExpansion(
            """
            actor Svc: ThrowingInitializable {
                @WaitForThrowingInit
                func complexSync() -> [String: Int] {
                    var dict = [String: Int]()
                    dict["a"] = 1
                    dict["b"] = 2
                    return dict
                }
            }
            """,
            expandedSource: """
            actor Svc: ThrowingInitializable {
                func complexSync() -> [String: Int] {
                    var dict = [String: Int]()
                    dict["a"] = 1
                    dict["b"] = 2
                    return dict
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForThrowingInit requires the function to be 'async throws'",
                    line: 2,
                    column: 5,
                    fixIts: [FixItSpec(message: "Add 'async throws'")]
                )
            ],
            macros: ["WaitForThrowingInit": WaitForThrowingInitMacro.self]
        )
    }
}

#endif
