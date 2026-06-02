//
//  AutoAwaitInitMacroTests.swift
//  InitializableTests
//
//  Tests for the `@AutoAwaitInit` member-attribute macro.
//
//  Validates that the macro correctly stamps `@WaitForInit` on qualifying async methods,
//  respects exclusion rules for protocol methods, skips non-function members, and emits
//  diagnostics for conformance errors and duplicate attribute detection.
//
//  Uses `assertMacroExpansion` from `SwiftSyntaxMacrosTestSupport` to verify
//  compile-time attribute stamping without running the generated code.
//

import Testing
import SwiftSyntaxMacrosTestSupport

#if canImport(InitializableMacros)
@testable import InitializableMacros

// MARK: - @AutoAwaitInit Member Attribute Macro Tests

/// Test suite for the `@AutoAwaitInit` member-attribute macro.
///
/// Covers four categories:
/// - **Happy path**: Verifies `@WaitForInit` is stamped on async methods.
/// - **Exclusions**: Protocol methods (`markInitialized`, `awaitInitialized`) are skipped.
/// - **Edge cases**: Non-function members, empty bodies, sync-only actors.
/// - **Diagnostics**: Non-conforming types and duplicate attribute detection with fix-its.
///
/// - SeeAlso: ``AutoAwaitInitMacro``
@Suite("@AutoAwaitInit Macro")
struct AutoAwaitInitMacroTests {

    // MARK: - Happy Path: Stamping

    /// Verifies that `@WaitForInit` is stamped on async methods and sync methods are skipped.
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

    /// Verifies that `@WaitForInit` is also stamped on `async throws` methods,
    /// since they are a superset of `async` methods.
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

    /// Verifies that `markInitialized` and `awaitInitialized` — the protocol's own methods —
    /// are excluded from stamping to prevent infinite recursion.
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

    /// Verifies that exclusion is by **exact** name match — methods with similar prefixes
    /// (e.g., `markInitializedData`) are NOT excluded.
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

    /// Verifies that `let`, `var`, and `init` declarations do not receive `@WaitForInit`.
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

    /// Verifies that an actor with no members produces no attributes.
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

    /// Verifies that an actor with only synchronous methods produces no `@WaitForInit` attributes.
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

    /// Verifies correct stamping on a method with a complex multi-parameter signature.
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

    /// Comprehensive test with all member kinds: properties, init, sync methods,
    /// async methods, async throwing methods, and excluded protocol methods.
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

    /// Verifies that applying `@AutoAwaitInit` to a type without `Initializable` conformance
    /// emits a "not conforming" error for each function member.
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

    /// Verifies that a manually-applied `@WaitForInit` under `@AutoAwaitInit` is diagnosed
    /// as redundant with a fix-it to remove it.
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

    /// Verifies that `@WaitForThrowingInit` under `@AutoAwaitInit` is also diagnosed as duplicate,
    /// since the wrong variant of the body macro was manually applied.
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
