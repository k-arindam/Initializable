//
//  AutoAwaitThrowingInitMacroTests.swift
//  InitializableTests
//
//  Tests for the @AutoAwaitThrowingInit member-attribute macro.
//  Verifies correct stamping of @WaitForThrowingInit, exclusion rules,
//  signature validation, diagnostics, and duplicate detection.
//

import Testing
import SwiftSyntaxMacrosTestSupport

#if canImport(InitializableMacros)
import InitializableMacros

// MARK: - @AutoAwaitThrowingInit Member Attribute Macro Tests

@Suite("@AutoAwaitThrowingInit Macro")
struct AutoAwaitThrowingInitMacroTests {

    // MARK: - Happy Path: Stamping on async throws methods

    @Test("Stamps @WaitForThrowingInit on async throws methods")
    func stampsOnAsyncThrowsMethods() {
        assertMacroExpansion(
            """
            @AutoAwaitThrowingInit
            actor MyService: ThrowingInitializable {
                func fetchData() async throws -> String { "data" }
                func save(_ item: String) async throws { }
            }
            """,
            expandedSource: """
            actor MyService: ThrowingInitializable {
                @WaitForThrowingInit
                func fetchData() async throws -> String { "data" }
                @WaitForThrowingInit
                func save(_ item: String) async throws { }
            }
            """,
            macros: ["AutoAwaitThrowingInit": AutoAwaitThrowingInitMacro.self]
        )
    }

    // MARK: - Happy Path: Exclusions

    @Test("Excludes markInitialized, markFailed, and awaitInitialized")
    func doesNotStampExcludedMethods() {
        assertMacroExpansion(
            """
            @AutoAwaitThrowingInit
            actor MyService: ThrowingInitializable {
                func markInitialized() async { }
                func markFailed() async { }
                func awaitInitialized() async throws { }
                func fetchData() async throws -> String { "data" }
            }
            """,
            expandedSource: """
            actor MyService: ThrowingInitializable {
                func markInitialized() async { }
                func markFailed() async { }
                func awaitInitialized() async throws { }
                @WaitForThrowingInit
                func fetchData() async throws -> String { "data" }
            }
            """,
            macros: ["AutoAwaitThrowingInit": AutoAwaitThrowingInitMacro.self]
        )
    }

    // MARK: - Edge Cases: Skipping non-async-throws signatures

    @Test("Skips sync methods — no attribute stamped")
    func skipsSyncMethods() {
        assertMacroExpansion(
            """
            @AutoAwaitThrowingInit
            actor MyService: ThrowingInitializable {
                func helper() -> String { "sync" }
                func compute(_ x: Int) -> Int { x * 2 }
            }
            """,
            expandedSource: """
            actor MyService: ThrowingInitializable {
                func helper() -> String { "sync" }
                func compute(_ x: Int) -> Int { x * 2 }
            }
            """,
            macros: ["AutoAwaitThrowingInit": AutoAwaitThrowingInitMacro.self]
        )
    }

    @Test("Skips throws-only methods — no attribute stamped")
    func skipsThrowsOnlyMethods() {
        assertMacroExpansion(
            """
            @AutoAwaitThrowingInit
            actor MyService: ThrowingInitializable {
                func riskyOp() throws -> Int { 42 }
            }
            """,
            expandedSource: """
            actor MyService: ThrowingInitializable {
                func riskyOp() throws -> Int { 42 }
            }
            """,
            macros: ["AutoAwaitThrowingInit": AutoAwaitThrowingInitMacro.self]
        )
    }

    // MARK: - Diagnostics: Async but Not Throwing

    @Test("Diagnoses async-only method — emits 'not throwing' with fix-it to add throws")
    func diagnosticAsyncNotThrowing() {
        assertMacroExpansion(
            """
            @AutoAwaitThrowingInit
            actor MyService: ThrowingInitializable {
                func fetchData() async -> String { "data" }
            }
            """,
            expandedSource: """
            actor MyService: ThrowingInitializable {
                func fetchData() async -> String { "data" }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForThrowingInit requires the function to be 'throws' because awaitInitialized() can throw",
                    line: 3,
                    column: 5,
                    fixIts: [FixItSpec(message: "Add 'throws'")]
                )
            ],
            macros: ["AutoAwaitThrowingInit": AutoAwaitThrowingInitMacro.self]
        )
    }

    // MARK: - Edge Cases: Non-Function Members

    @Test("Does not stamp properties, initializers")
    func doesNotStampNonMethods() {
        assertMacroExpansion(
            """
            @AutoAwaitThrowingInit
            actor MyService: ThrowingInitializable {
                let name: String
                var count = 0
                init() { name = "test" }
                func fetchData() async throws -> String { "data" }
            }
            """,
            expandedSource: """
            actor MyService: ThrowingInitializable {
                let name: String
                var count = 0
                init() { name = "test" }
                @WaitForThrowingInit
                func fetchData() async throws -> String { "data" }
            }
            """,
            macros: ["AutoAwaitThrowingInit": AutoAwaitThrowingInitMacro.self]
        )
    }

    @Test("Empty actor body produces no attributes")
    func emptyActorBody() {
        assertMacroExpansion(
            """
            @AutoAwaitThrowingInit
            actor EmptyService: ThrowingInitializable {
            }
            """,
            expandedSource: """
            actor EmptyService: ThrowingInitializable {
            }
            """,
            macros: ["AutoAwaitThrowingInit": AutoAwaitThrowingInitMacro.self]
        )
    }

    @Test("Mix of all member kinds — stamps only async throws methods")
    func mixOfAllMemberKinds() {
        assertMacroExpansion(
            """
            @AutoAwaitThrowingInit
            actor FullService: ThrowingInitializable {
                let id: String
                var counter = 0
                init(id: String) { self.id = id }
                func syncMethod() -> Int { 1 }
                func asyncOnly() async -> Int { 2 }
                func throwsOnly() throws -> Int { 3 }
                func asyncThrows() async throws -> String { "" }
                func markInitialized() async { }
                func markFailed() async { }
                func awaitInitialized() async throws { }
            }
            """,
            expandedSource: """
            actor FullService: ThrowingInitializable {
                let id: String
                var counter = 0
                init(id: String) { self.id = id }
                func syncMethod() -> Int { 1 }
                func asyncOnly() async -> Int { 2 }
                func throwsOnly() throws -> Int { 3 }
                @WaitForThrowingInit
                func asyncThrows() async throws -> String { "" }
                func markInitialized() async { }
                func markFailed() async { }
                func awaitInitialized() async throws { }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForThrowingInit requires the function to be 'throws' because awaitInitialized() can throw",
                    line: 6,
                    column: 5,
                    fixIts: [FixItSpec(message: "Add 'throws'")]
                )
            ],
            macros: ["AutoAwaitThrowingInit": AutoAwaitThrowingInitMacro.self]
        )
    }

    // MARK: - Diagnostics: Not Conforming

    @Test("Diagnoses when type does not conform to ThrowingInitializable")
    func diagnosticNotConforming() {
        assertMacroExpansion(
            """
            @AutoAwaitThrowingInit
            actor MyService {
                func fetchData() async throws -> String { "data" }
            }
            """,
            expandedSource: """
            actor MyService {
                func fetchData() async throws -> String { "data" }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@AutoAwaitThrowingInit can only be applied to a type that conforms to 'ThrowingInitializable'",
                    line: 1,
                    column: 1
                )
            ],
            macros: ["AutoAwaitThrowingInit": AutoAwaitThrowingInitMacro.self]
        )
    }

    // MARK: - Diagnostics: Duplicate @WaitForThrowingInit

    @Test("Diagnoses duplicate @WaitForThrowingInit on a member with fix-it to remove")
    func diagnosticDuplicateWaitForThrowingInit() {
        assertMacroExpansion(
            """
            @AutoAwaitThrowingInit
            actor MyService: ThrowingInitializable {
                @WaitForThrowingInit
                func fetchData() async throws -> String { "data" }
            }
            """,
            expandedSource: """
            actor MyService: ThrowingInitializable {
                @WaitForThrowingInit
                func fetchData() async throws -> String { "data" }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForThrowingInit should not be added manually when @AutoAwaitThrowingInit is applied to the enclosing type",
                    line: 3,
                    column: 5,
                    fixIts: [FixItSpec(message: "Remove @WaitForThrowingInit")]
                )
            ],
            macros: ["AutoAwaitThrowingInit": AutoAwaitThrowingInitMacro.self]
        )
    }

    @Test("Diagnoses duplicate @WaitForInit on a member under @AutoAwaitThrowingInit")
    func diagnosticDuplicateWaitForInit() {
        assertMacroExpansion(
            """
            @AutoAwaitThrowingInit
            actor MyService: ThrowingInitializable {
                @WaitForInit
                func fetchData() async throws -> String { "data" }
            }
            """,
            expandedSource: """
            actor MyService: ThrowingInitializable {
                @WaitForInit
                func fetchData() async throws -> String { "data" }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForInit should not be added manually when @AutoAwaitThrowingInit is applied to the enclosing type",
                    line: 3,
                    column: 5,
                    fixIts: [FixItSpec(message: "Remove @WaitForInit")]
                )
            ],
            macros: ["AutoAwaitThrowingInit": AutoAwaitThrowingInitMacro.self]
        )
    }
}

#endif
