//
//  AutoAwaitInitMacroTests.swift
//  InitializableTests
//
//  Tests for the @AutoAwaitInit member-attribute macro.
//  Verifies correct stamping of @WaitForInit, exclusion rules, diagnostics,
//  and duplicate detection.
//

import Testing
import SwiftSyntaxMacrosTestSupport

#if canImport(InitializableMacros)
import InitializableMacros

// MARK: - @AutoAwaitInit Member Attribute Macro Tests

@Suite("@AutoAwaitInit Macro")
struct AutoAwaitInitMacroTests {

    // MARK: - Happy Path: Stamping

    @Test("Stamps @WaitForInit on async methods only")
    func stampsWaitForInitOnAsyncMethods() {
        assertMacroExpansion(
            """
            @AutoAwaitInit
            actor MyService: Initializable {
                func fetchData() async -> String { "data" }
                func syncHelper() -> String { "sync" }
                func process() async { }
            }
            """,
            expandedSource: """
            actor MyService: Initializable {
                @WaitForInit
                func fetchData() async -> String { "data" }
                func syncHelper() -> String { "sync" }
                @WaitForInit
                func process() async { }
            }
            """,
            macros: ["AutoAwaitInit": AutoAwaitInitMacro.self]
        )
    }

    @Test("Stamps @WaitForInit on async throwing methods too")
    func stampsOnAsyncThrowingMethods() {
        assertMacroExpansion(
            """
            @AutoAwaitInit
            actor MyService: Initializable {
                func load() async throws -> Data { Data() }
                func save(_ item: String) async throws { }
            }
            """,
            expandedSource: """
            actor MyService: Initializable {
                @WaitForInit
                func load() async throws -> Data { Data() }
                @WaitForInit
                func save(_ item: String) async throws { }
            }
            """,
            macros: ["AutoAwaitInit": AutoAwaitInitMacro.self]
        )
    }

    // MARK: - Happy Path: Exclusions

    @Test("Does not stamp excluded protocol methods (markInitialized, awaitInitialized)")
    func doesNotStampExcludedMethods() {
        assertMacroExpansion(
            """
            @AutoAwaitInit
            actor MyService: Initializable {
                func markInitialized() async { }
                func awaitInitialized() async { }
                func fetchData() async -> String { "data" }
            }
            """,
            expandedSource: """
            actor MyService: Initializable {
                func markInitialized() async { }
                func awaitInitialized() async { }
                @WaitForInit
                func fetchData() async -> String { "data" }
            }
            """,
            macros: ["AutoAwaitInit": AutoAwaitInitMacro.self]
        )
    }

    @Test("Excludes only exact protocol method names, not similarly-prefixed ones")
    func doesNotExcludeSimilarNames() {
        assertMacroExpansion(
            """
            @AutoAwaitInit
            actor MyService: Initializable {
                func markInitializedData() async { }
                func awaitInitializedResult() async -> Int { 0 }
            }
            """,
            expandedSource: """
            actor MyService: Initializable {
                @WaitForInit
                func markInitializedData() async { }
                @WaitForInit
                func awaitInitializedResult() async -> Int { 0 }
            }
            """,
            macros: ["AutoAwaitInit": AutoAwaitInitMacro.self]
        )
    }

    // MARK: - Edge Cases: Non-Function Members

    @Test("Does not stamp properties, initializers, or subscripts")
    func doesNotStampNonMethods() {
        assertMacroExpansion(
            """
            @AutoAwaitInit
            actor MyService: Initializable {
                let name: String
                var count = 0
                init() { name = "test" }
                func fetchData() async -> String { "data" }
            }
            """,
            expandedSource: """
            actor MyService: Initializable {
                let name: String
                var count = 0
                init() { name = "test" }
                @WaitForInit
                func fetchData() async -> String { "data" }
            }
            """,
            macros: ["AutoAwaitInit": AutoAwaitInitMacro.self]
        )
    }

    @Test("Empty actor body produces no attributes")
    func emptyActorBody() {
        assertMacroExpansion(
            """
            @AutoAwaitInit
            actor EmptyService: Initializable {
            }
            """,
            expandedSource: """
            actor EmptyService: Initializable {
            }
            """,
            macros: ["AutoAwaitInit": AutoAwaitInitMacro.self]
        )
    }

    @Test("Actor with only sync methods produces no attributes")
    func noAttributesForSyncOnlyActor() {
        assertMacroExpansion(
            """
            @AutoAwaitInit
            actor MyService: Initializable {
                func helper() -> String { "sync" }
                func compute(_ x: Int) -> Int { x * 2 }
            }
            """,
            expandedSource: """
            actor MyService: Initializable {
                func helper() -> String { "sync" }
                func compute(_ x: Int) -> Int { x * 2 }
            }
            """,
            macros: ["AutoAwaitInit": AutoAwaitInitMacro.self]
        )
    }

    @Test("Complex async signature gets stamped correctly")
    func complexAsyncSignature() {
        assertMacroExpansion(
            """
            @AutoAwaitInit
            actor MyService: Initializable {
                func update(id: Int, name: String, tags: [String]) async throws -> Bool { true }
            }
            """,
            expandedSource: """
            actor MyService: Initializable {
                @WaitForInit
                func update(id: Int, name: String, tags: [String]) async throws -> Bool { true }
            }
            """,
            macros: ["AutoAwaitInit": AutoAwaitInitMacro.self]
        )
    }

    @Test("Mix of all member kinds — stamps only async methods")
    func mixOfAllMemberKinds() {
        assertMacroExpansion(
            """
            @AutoAwaitInit
            actor FullService: Initializable {
                let id: String
                var counter = 0
                init(id: String) { self.id = id }
                func syncMethod() -> Int { 1 }
                func asyncMethod() async -> Int { 2 }
                func asyncThrowingMethod() async throws -> String { "" }
                func markInitialized() async { }
                func awaitInitialized() async { }
            }
            """,
            expandedSource: """
            actor FullService: Initializable {
                let id: String
                var counter = 0
                init(id: String) { self.id = id }
                func syncMethod() -> Int { 1 }
                @WaitForInit
                func asyncMethod() async -> Int { 2 }
                @WaitForInit
                func asyncThrowingMethod() async throws -> String { "" }
                func markInitialized() async { }
                func awaitInitialized() async { }
            }
            """,
            macros: ["AutoAwaitInit": AutoAwaitInitMacro.self]
        )
    }

    // MARK: - Diagnostics: Not Conforming

    @Test("Diagnoses when type does not conform to Initializable")
    func diagnosticNotConforming() {
        assertMacroExpansion(
            """
            @AutoAwaitInit
            actor MyService {
                func fetchData() async -> String { "data" }
            }
            """,
            expandedSource: """
            actor MyService {
                func fetchData() async -> String { "data" }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@AutoAwaitInit can only be applied to a type that conforms to 'Initializable'",
                    line: 1,
                    column: 1
                )
            ],
            macros: ["AutoAwaitInit": AutoAwaitInitMacro.self]
        )
    }

    // MARK: - Diagnostics: Duplicate @WaitForInit

    @Test("Diagnoses duplicate @WaitForInit on a member with fix-it to remove it")
    func diagnosticDuplicateWaitForInit() {
        assertMacroExpansion(
            """
            @AutoAwaitInit
            actor MyService: Initializable {
                @WaitForInit
                func fetchData() async -> String { "data" }
            }
            """,
            expandedSource: """
            actor MyService: Initializable {
                @WaitForInit
                func fetchData() async -> String { "data" }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForInit should not be added manually when @AutoAwaitInit is applied to the enclosing type",
                    line: 3,
                    column: 5,
                    fixIts: [FixItSpec(message: "Remove @WaitForInit")]
                )
            ],
            macros: ["AutoAwaitInit": AutoAwaitInitMacro.self]
        )
    }

    @Test("Diagnoses duplicate @WaitForThrowingInit on a member under @AutoAwaitInit")
    func diagnosticDuplicateWaitForThrowingInit() {
        assertMacroExpansion(
            """
            @AutoAwaitInit
            actor MyService: Initializable {
                @WaitForThrowingInit
                func fetchData() async -> String { "data" }
            }
            """,
            expandedSource: """
            actor MyService: Initializable {
                @WaitForThrowingInit
                func fetchData() async -> String { "data" }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForThrowingInit should not be added manually when @AutoAwaitInit is applied to the enclosing type",
                    line: 3,
                    column: 5,
                    fixIts: [FixItSpec(message: "Remove @WaitForThrowingInit")]
                )
            ],
            macros: ["AutoAwaitInit": AutoAwaitInitMacro.self]
        )
    }
}

#endif
