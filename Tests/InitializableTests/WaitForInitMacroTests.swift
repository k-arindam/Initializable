//
//  WaitForInitMacroTests.swift
//  InitializableTests
//
//  Tests for the @WaitForInit body macro.
//  Verifies correct code injection, diagnostic emission, and fix-it suggestions.
//

import Testing
import SwiftSyntaxMacrosTestSupport

#if canImport(InitializableMacros)
import InitializableMacros

// MARK: - @WaitForInit Body Macro Tests

@Suite("@WaitForInit Macro")
struct WaitForInitMacroTests {

    // MARK: - Happy Path: Code Injection

    @Test("Prepends 'await awaitInitialized()' to async function body")
    func prependsAwaitInitialized() {
        assertMacroExpansion(
            """
            actor Svc: Initializable {
                @WaitForInit
                func fetchData() async -> String {
                    return "data"
                }
            }
            """,
            expandedSource: """
            actor Svc: Initializable {
                func fetchData() async -> String {
                    await awaitInitialized()
                    return "data"
                }
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Preserves multi-statement body")
    func preservesMultiStatementBody() {
        assertMacroExpansion(
            """
            actor Svc: Initializable {
                @WaitForInit
                func process(_ id: Int) async {
                    let value = id * 2
                    print(value)
                }
            }
            """,
            expandedSource: """
            actor Svc: Initializable {
                func process(_ id: Int) async {
                    await awaitInitialized()
                    let value = id * 2
                    print(value)
                }
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Preserves guard statements in body")
    func preservesGuardStatements() {
        assertMacroExpansion(
            """
            actor Svc: Initializable {
                @WaitForInit
                func validate(_ input: String?) async -> Bool {
                    guard let input else { return false }
                    return !input.isEmpty
                }
            }
            """,
            expandedSource: """
            actor Svc: Initializable {
                func validate(_ input: String?) async -> Bool {
                    await awaitInitialized()
                    guard let input else { return false }
                    return !input.isEmpty
                }
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Preserves closures in body")
    func preservesClosureInBody() {
        assertMacroExpansion(
            """
            actor Svc: Initializable {
                @WaitForInit
                func fetchAll() async -> [String] {
                    let items = [1, 2, 3].map { "\\($0)" }
                    return items
                }
            }
            """,
            expandedSource: """
            actor Svc: Initializable {
                func fetchAll() async -> [String] {
                    await awaitInitialized()
                    let items = [1, 2, 3].map { "\\($0)" }
                    return items
                }
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Preserves control flow in body")
    func preservesControlFlow() {
        assertMacroExpansion(
            """
            actor Svc: Initializable {
                @WaitForInit
                func compute(_ values: [Int]) async -> Int {
                    var sum = 0
                    for value in values {
                        if value > 0 {
                            sum += value
                        }
                    }
                    return sum
                }
            }
            """,
            expandedSource: """
            actor Svc: Initializable {
                func compute(_ values: [Int]) async -> Int {
                    await awaitInitialized()
                    var sum = 0
                    for value in values {
                        if value > 0 {
                            sum += value
                        }
                    }
                    return sum
                }
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Preserves try/catch in body")
    func preservesTryCatchInBody() {
        assertMacroExpansion(
            """
            actor Svc: Initializable {
                @WaitForInit
                func safeFetch() async -> String {
                    do {
                        return try String(contentsOfFile: "path")
                    } catch {
                        return "fallback"
                    }
                }
            }
            """,
            expandedSource: """
            actor Svc: Initializable {
                func safeFetch() async -> String {
                    await awaitInitialized()
                    do {
                        return try String(contentsOfFile: "path")
                    } catch {
                        return "fallback"
                    }
                }
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Works with async throwing function — still injects non-throwing await")
    func asyncThrowingFunction() {
        assertMacroExpansion(
            """
            actor Svc: Initializable {
                @WaitForInit
                func fetchData() async throws -> String {
                    return try await loadFromNetwork()
                }
            }
            """,
            expandedSource: """
            actor Svc: Initializable {
                func fetchData() async throws -> String {
                    await awaitInitialized()
                    return try await loadFromNetwork()
                }
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    // MARK: - Edge Cases

    @Test("Empty async function body gets await injected")
    func emptyBodyAsyncFunction() {
        assertMacroExpansion(
            """
            actor Svc: Initializable {
                @WaitForInit
                func noOp() async {
                }
            }
            """,
            expandedSource: """
            actor Svc: Initializable {
                func noOp() async {
                    await awaitInitialized()
                }
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Complex return type and multiple parameters")
    func complexReturnTypeAndParams() {
        assertMacroExpansion(
            """
            actor Svc: Initializable {
                @WaitForInit
                func process(_ data: [String], count: Int) async throws -> (success: Bool, message: String) {
                    return (true, "ok")
                }
            }
            """,
            expandedSource: """
            actor Svc: Initializable {
                func process(_ data: [String], count: Int) async throws -> (success: Bool, message: String) {
                    await awaitInitialized()
                    return (true, "ok")
                }
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Explicit -> Void return type")
    func asyncFunctionReturningVoidExplicitly() {
        assertMacroExpansion(
            """
            actor Svc: Initializable {
                @WaitForInit
                func doWork() async -> Void {
                    print("working")
                }
            }
            """,
            expandedSource: """
            actor Svc: Initializable {
                func doWork() async -> Void {
                    await awaitInitialized()
                    print("working")
                }
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    // MARK: - Diagnostics: Not Async

    @Test("Diagnoses sync function — emits 'not async' error with fix-it")
    func diagnosticOnSyncVoidMethod() {
        assertMacroExpansion(
            """
            actor Svc: Initializable {
                @WaitForInit
                func setup() {
                    print("setup")
                }
            }
            """,
            expandedSource: """
            actor Svc: Initializable {
                func setup() {
                    print("setup")
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForInit requires the function to be 'async'",
                    line: 2,
                    column: 5,
                    fixIts: [FixItSpec(message: "Add 'async'")]
                )
            ],
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Diagnoses sync function with return value — emits 'not async' error with fix-it")
    func diagnosticOnSyncMethodWithReturn() {
        assertMacroExpansion(
            """
            actor Svc: Initializable {
                @WaitForInit
                func syncMethod() -> String {
                    return "hello"
                }
            }
            """,
            expandedSource: """
            actor Svc: Initializable {
                func syncMethod() -> String {
                    return "hello"
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForInit requires the function to be 'async'",
                    line: 2,
                    column: 5,
                    fixIts: [FixItSpec(message: "Add 'async'")]
                )
            ],
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Diagnoses sync throwing function — emits 'not async' error with fix-it")
    func diagnosticOnSyncThrowingMethod() {
        assertMacroExpansion(
            """
            actor Svc: Initializable {
                @WaitForInit
                func riskyOperation() throws -> Int {
                    return 42
                }
            }
            """,
            expandedSource: """
            actor Svc: Initializable {
                func riskyOperation() throws -> Int {
                    return 42
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForInit requires the function to be 'async'",
                    line: 2,
                    column: 5,
                    fixIts: [FixItSpec(message: "Add 'async'")]
                )
            ],
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    // MARK: - Diagnostics: Not Conforming

    @Test("Diagnoses when enclosing type does not conform to Initializable")
    func diagnosticNotConforming() {
        assertMacroExpansion(
            """
            actor Svc {
                @WaitForInit
                func fetchData() async -> String {
                    return "data"
                }
            }
            """,
            expandedSource: """
            actor Svc {
                func fetchData() async -> String {
                    return "data"
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForInit can only be used in a type that conforms to 'Initializable'",
                    line: 2,
                    column: 5
                )
            ],
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    // MARK: - Diagnostics: Not In Type

    @Test("Diagnoses when applied at free-function scope (no enclosing type)")
    func diagnosticNotInType() {
        assertMacroExpansion(
            """
            @WaitForInit
            func freeFunction() async {
                print("hello")
            }
            """,
            expandedSource: """
            func freeFunction() async {
                print("hello")
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForInit can only be applied inside a type declaration",
                    line: 1,
                    column: 1
                )
            ],
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }
}

#endif
