//
//  WaitForThrowingInitMacroTests.swift
//  InitializableTests
//
//  Tests for the @WaitForThrowingInit body macro.
//  Verifies correct code injection, all diagnostic branches, and fix-it suggestions.
//

import Testing
import SwiftSyntaxMacrosTestSupport

#if canImport(InitializableMacros)
import InitializableMacros

// MARK: - @WaitForThrowingInit Body Macro Tests

@Suite("@WaitForThrowingInit Macro")
struct WaitForThrowingInitMacroTests {

    // MARK: - Happy Path: Code Injection (async throws)

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
