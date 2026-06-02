//
//  SkipInitMacroTests.swift
//  InitializableTests
//
//  Created by Arindam Karmakar on 02/06/26.
//

import Testing
import SwiftSyntaxMacrosTestSupport

#if canImport(InitializableMacros)
@testable import InitializableMacros

@Suite("SkipInit Macro")
struct SkipInitMacroTests {
    
    @Test("Skips stamping on @SkipInit async method")
    func skipsStampingOnSkipInit() {
        assertMacroExpansion(
            """
            @AutoAwaitInit
            actor MyService: Initializable {
                @SkipInit
                func fetchData() async -> String { "data" }
                func process() async -> String { "process" }
            }
            """,
            expandedSource: """
            actor MyService: Initializable {
                @SkipInit
                func fetchData() async -> String { "data" }
                @WaitForInit
                func process() async -> String { "process" }
            }
            """,
            macros: ["AutoAwaitInit": AutoAwaitInitMacro.self]
        )
    }
    
    @Test("Errors when @SkipInit is used on a sync function")
    func errorsOnSyncFunction() {
        assertMacroExpansion(
            """
            @AutoAwaitInit
            actor MyService: Initializable {
                @SkipInit
                func syncMethod() -> String { "data" }
            }
            """,
            expandedSource: """
            actor MyService: Initializable {
                func syncMethod() -> String { "data" }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@SkipInit can only be applied to async functions — sync functions are never wrapped",
                    line: 3,
                    column: 5,
                    severity: .error,
                    fixIts: [FixItSpec(message: "Remove '@SkipInit'")]
                )
            ],
            macros: ["SkipInit": SkipInitMacro.self]
        )
    }
    
    @Test("Errors when @SkipInit is used without @AutoAwaitInit on enclosing type")
    func errorsWithoutAutoAwaitInit() {
        assertMacroExpansion(
            """
            actor MyService: Initializable {
                @SkipInit
                func fetchData() async -> String { "data" }
            }
            """,
            expandedSource: """
            actor MyService: Initializable {
                func fetchData() async -> String { "data" }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@SkipInit can only be used inside a type marked with @AutoAwaitInit or @AutoAwaitThrowingInit",
                    line: 2,
                    column: 5,
                    severity: .error,
                    fixIts: [FixItSpec(message: "Remove '@SkipInit'")]
                )
            ],
            macros: ["SkipInit": SkipInitMacro.self]
        )
    }
    
    @Test("Errors when @SkipInit is used without any enclosing type")
    func errorsOutsideType() {
        assertMacroExpansion(
            """
            @SkipInit
            func fetchData() async -> String { "data" }
            """,
            expandedSource: """
            func fetchData() async -> String { "data" }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@SkipInit can only be used inside a type marked with @AutoAwaitInit or @AutoAwaitThrowingInit",
                    line: 1,
                    column: 1,
                    severity: .error,
                    fixIts: [FixItSpec(message: "Remove '@SkipInit'")]
                )
            ],
            macros: ["SkipInit": SkipInitMacro.self]
        )
    }
}

#endif
