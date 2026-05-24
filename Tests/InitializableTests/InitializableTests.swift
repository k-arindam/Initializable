import Testing
import SwiftSyntaxMacrosTestSupport
@testable import InitializableMacros

// MARK: - AutoAwaitInit Macro Tests

@Suite("AutoAwaitInit Macro")
struct AutoAwaitInitMacroTests {

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

    @Test("Does not stamp excluded protocol methods")
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

    @Test("Stamps @WaitForInit on async throwing methods")
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

    @Test("Produces no attributes for actor with only sync methods")
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

    @Test("Handles actor with empty body")
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

    @Test("Handles async method with complex signature")
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

    @Test("Excludes only named protocol methods, not similarly prefixed names")
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

    @Test("Handles mix of all member kinds")
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
}

// MARK: - WaitForInit Macro Tests

@Suite("WaitForInit Macro")
struct WaitForInitMacroTests {

    @Test("Prepends awaitInitialized to function body")
    func prependsAwaitInitialized() {
        assertMacroExpansion(
            """
            @WaitForInit
            func fetchData() async -> String {
                return "data"
            }
            """,
            expandedSource: """
            func fetchData() async -> String {
                await awaitInitialized()
                return "data"
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Preserves multi-statement body")
    func preservesMultiStatementBody() {
        assertMacroExpansion(
            """
            @WaitForInit
            func process(_ id: Int) async {
                let value = id * 2
                print(value)
            }
            """,
            expandedSource: """
            func process(_ id: Int) async {
                await awaitInitialized()
                let value = id * 2
                print(value)
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Emits error diagnostic when applied to sync method with return value")
    func diagnosticOnSyncMethodWithReturn() {
        assertMacroExpansion(
            """
            @WaitForInit
            func syncMethod() -> String {
                return "hello"
            }
            """,
            expandedSource: """
            func syncMethod() -> String {
                return "hello"
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForInit can only be applied to async functions",
                    line: 1,
                    column: 1,
                    fixIts: [FixItSpec(message: "Add 'async'")]
                )
            ],
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Emits error diagnostic when applied to sync void method")
    func diagnosticOnSyncVoidMethod() {
        assertMacroExpansion(
            """
            @WaitForInit
            func setup() {
                print("setup")
            }
            """,
            expandedSource: """
            func setup() {
                print("setup")
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForInit can only be applied to async functions",
                    line: 1,
                    column: 1,
                    fixIts: [FixItSpec(message: "Add 'async'")]
                )
            ],
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Emits error diagnostic when applied to sync throwing method")
    func diagnosticOnSyncThrowingMethod() {
        assertMacroExpansion(
            """
            @WaitForInit
            func riskyOperation() throws -> Int {
                return 42
            }
            """,
            expandedSource: """
            func riskyOperation() throws -> Int {
                return 42
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@WaitForInit can only be applied to async functions",
                    line: 1,
                    column: 1,
                    fixIts: [FixItSpec(message: "Add 'async'")]
                )
            ],
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Handles async throwing function")
    func asyncThrowingFunction() {
        assertMacroExpansion(
            """
            @WaitForInit
            func fetchData() async throws -> String {
                return try await loadFromNetwork()
            }
            """,
            expandedSource: """
            func fetchData() async throws -> String {
                await awaitInitialized()
                return try await loadFromNetwork()
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Handles empty body async function")
    func emptyBodyAsyncFunction() {
        assertMacroExpansion(
            """
            @WaitForInit
            func noOp() async {
            }
            """,
            expandedSource: """
            func noOp() async {
                await awaitInitialized()
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Preserves body with guard statements")
    func preservesGuardStatements() {
        assertMacroExpansion(
            """
            @WaitForInit
            func validate(_ input: String?) async -> Bool {
                guard let input else { return false }
                return !input.isEmpty
            }
            """,
            expandedSource: """
            func validate(_ input: String?) async -> Bool {
                await awaitInitialized()
                guard let input else { return false }
                return !input.isEmpty
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Handles complex return type and multiple parameters")
    func complexReturnTypeAndParams() {
        assertMacroExpansion(
            """
            @WaitForInit
            func process(_ data: [String], count: Int) async throws -> (success: Bool, message: String) {
                return (true, "ok")
            }
            """,
            expandedSource: """
            func process(_ data: [String], count: Int) async throws -> (success: Bool, message: String) {
                await awaitInitialized()
                return (true, "ok")
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Preserves body with closures")
    func preservesClosureInBody() {
        assertMacroExpansion(
            """
            @WaitForInit
            func fetchAll() async -> [String] {
                let items = [1, 2, 3].map { "\\($0)" }
                return items
            }
            """,
            expandedSource: """
            func fetchAll() async -> [String] {
                await awaitInitialized()
                let items = [1, 2, 3].map { "\\($0)" }
                return items
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Preserves body with control flow")
    func preservesControlFlow() {
        assertMacroExpansion(
            """
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
            """,
            expandedSource: """
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
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Handles async function returning Void explicitly")
    func asyncFunctionReturningVoidExplicitly() {
        assertMacroExpansion(
            """
            @WaitForInit
            func doWork() async -> Void {
                print("working")
            }
            """,
            expandedSource: """
            func doWork() async -> Void {
                await awaitInitialized()
                print("working")
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }

    @Test("Handles async function with try/catch in body")
    func preservesTryCatchInBody() {
        assertMacroExpansion(
            """
            @WaitForInit
            func safeFetch() async -> String {
                do {
                    return try String(contentsOfFile: "path")
                } catch {
                    return "fallback"
                }
            }
            """,
            expandedSource: """
            func safeFetch() async -> String {
                await awaitInitialized()
                do {
                    return try String(contentsOfFile: "path")
                } catch {
                    return "fallback"
                }
            }
            """,
            macros: ["WaitForInit": WaitForInitMacro.self]
        )
    }
}
