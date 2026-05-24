import Testing
import SwiftSyntaxMacrosTestSupport
@testable import InitializableMacros

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
}

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
}
