//
//  SkipInitMacroTests.swift
//  InitializableTests
//
//  Unit tests for the ``SkipInitMacro`` peer macro. Verifies that `@SkipInit`
//  correctly opts methods out of automatic `@WaitForInit` stamping by
//  `@AutoAwaitInit`, and that appropriate diagnostics are emitted for
//  invalid usage (non-async functions, missing enclosing `@AutoAwait*` macro).
//
//  Created by Arindam Karmakar on 02/06/26.
//

import Testing
import SwiftSyntaxMacrosTestSupport

#if canImport(InitializableMacros)
@testable import InitializableMacros

/// Tests for the `@SkipInit` peer macro.
///
/// Validates the following behaviors:
/// - Methods annotated with `@SkipInit` are excluded from `@AutoAwaitInit` stamping.
/// - Applying `@SkipInit` to a synchronous function produces an error with a removal fix-it.
/// - Applying `@SkipInit` without an enclosing `@AutoAwaitInit`/`@AutoAwaitThrowingInit` produces an error.
/// - Applying `@SkipInit` outside any type declaration produces an error.
@Suite("SkipInit Macro")
struct SkipInitMacroTests {
    
    /// Verifies that `@AutoAwaitInit` skips stamping `@WaitForInit` on a method
    /// decorated with `@SkipInit`, while still stamping other async methods normally.
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
    
    /// Verifies that `@SkipInit` on a synchronous function emits an error diagnostic
    /// with a fix-it suggesting removal of the attribute.
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
    
    /// Verifies that `@SkipInit` emits an error when the enclosing type does not
    /// have `@AutoAwaitInit` or `@AutoAwaitThrowingInit` applied.
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
    
    /// Verifies that `@SkipInit` emits an error when applied to a free function
    /// (outside any type declaration), since there is no `@AutoAwait*` context.
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
