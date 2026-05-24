//
//  WaitForInitMacro.swift
//  InitializableMacros
//
//  Body macro implementations that inject initialization-gating calls
//  at the start of function bodies. These are the leaf macros that
//  perform the actual code generation — `@AutoAwaitInit` delegates to them.
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation
import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros

// MARK: - WaitForInitMacro (Non-Throwing Body Macro)

/// A body macro that prepends `await awaitInitialized()` to the function body.
///
/// When attached to an `async` function inside a type conforming to `Initializable`,
/// this macro injects a single suspension statement at the beginning of the function
/// body. This ensures the function waits for the initialization gate to open before
/// executing any user-defined logic.
///
/// ## Expansion
/// ```swift
/// // Input:
/// @WaitForInit
/// func fetchData() async -> String {
///     return "data"
/// }
///
/// // Expanded output:
/// func fetchData() async -> String {
///     await awaitInitialized()
///     return "data"
/// }
/// ```
///
/// ## Validation & Diagnostics
/// The macro performs three validation checks before injecting code:
/// 1. **Enclosing type**: Must be inside an actor, class, or struct.
///    → ``WaitForInitDiagnostic/notInType(throwing:)``
/// 2. **Protocol conformance**: Enclosing type must conform to `Initializable`.
///    → ``WaitForInitDiagnostic/notConforming(throwing:)``
/// 3. **Async requirement**: The function must be `async`.
///    → ``WaitForInitDiagnostic/notAsync(throwing:)`` with fix-it to add `async`.
///
/// On any validation failure, the original body is returned unchanged.
///
/// - SeeAlso: ``WaitForThrowingInitMacro``, ``AutoAwaitInitMacro``
public struct WaitForInitMacro: BodyMacro {
    /// Generates the body for the attached function declaration.
    ///
    /// - Parameters:
    ///   - node: The `@WaitForInit` attribute syntax node.
    ///   - declaration: The function declaration this macro is attached to.
    ///   - context: The macro expansion context for diagnostics and lexical context lookup.
    /// - Returns: An array of `CodeBlockItemSyntax` representing the new function body.
    ///   On success, prepends `await awaitInitialized()` to the original statements.
    ///   On failure, returns the original statements unchanged.
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self),
              let body = funcDecl.body
        else { return [] }
        
        let originalStatements = body.statements.map { $0 }
        
        // Validation 1: Must be inside a type declaration
        guard let enclosing = funcDecl.enclosingTypeDecl(in: context) else {
            context.diagnose(Diagnostic(
                node: node,
                message: WaitForInitDiagnostic.notInType(throwing: false)
            ))
            return originalStatements
        }
        
        // Validation 2: Enclosing type must conform to Initializable
        guard funcDecl.conformsToInitializable(enclosing, with: "Initializable") else {
            context.diagnose(Diagnostic(
                node: node,
                message: WaitForInitDiagnostic.notConforming(throwing: false)
            ))
            return originalStatements
        }
        
        // Validation 3: Function must be async
        if !funcDecl.isAsync {
            context.diagnose(Diagnostic(
                node: node,
                message: WaitForInitDiagnostic.notAsync(throwing: false),
                fixIts: [
                    FixIt(
                        message: WaitForInitFixIt.addAsync,
                        changes: [
                            .replace(
                                oldNode: Syntax(funcDecl.signature),
                                newNode: Syntax(funcDecl.addingAsync())
                            )
                        ]
                    )
                ]
            ))
            return originalStatements
        }
        
        // ✅ All validations passed — inject the await call
        return ["await awaitInitialized()"] + body.statements
    }
}

// MARK: - WaitForThrowingInitMacro (Throwing Body Macro)

/// A body macro that prepends `try await awaitInitialized()` to the function body.
///
/// When attached to an `async throws` function inside a type conforming to
/// `ThrowingInitializable`, this macro injects a throwing suspension statement
/// at the beginning of the function body. If initialization failed, the injected
/// call will re-throw the stored error.
///
/// ## Expansion
/// ```swift
/// // Input:
/// @WaitForThrowingInit
/// func query() async throws -> [Row] {
///     return try await db.execute(sql)
/// }
///
/// // Expanded output:
/// func query() async throws -> [Row] {
///     try await awaitInitialized()
///     return try await db.execute(sql)
/// }
/// ```
///
/// ## Validation & Diagnostics
/// The macro validates **four** conditions, covering all combinations of `async`/`throws`:
///
/// | Async | Throws | Result |
/// |-------|--------|--------|
/// | ✅    | ✅     | Injects `try await awaitInitialized()` |
/// | ❌    | ❌     | ``WaitForInitDiagnostic/notAsyncThrowing`` — fix-it: add `async throws` |
/// | ❌    | ✅     | ``WaitForInitDiagnostic/notAsync(throwing:)`` — fix-it: add `async` |
/// | ✅    | ❌     | ``WaitForInitDiagnostic/notThrowing`` — fix-it: add `throws` |
///
/// Additionally validates enclosing type existence and `ThrowingInitializable` conformance.
///
/// - SeeAlso: ``WaitForInitMacro``, ``AutoAwaitThrowingInitMacro``
public struct WaitForThrowingInitMacro: BodyMacro {
    /// Generates the body for the attached function declaration.
    ///
    /// - Parameters:
    ///   - node: The `@WaitForThrowingInit` attribute syntax node.
    ///   - declaration: The function declaration this macro is attached to.
    ///   - context: The macro expansion context for diagnostics and lexical context lookup.
    /// - Returns: An array of `CodeBlockItemSyntax` representing the new function body.
    ///   On success, prepends `try await awaitInitialized()` to the original statements.
    ///   On failure, returns the original statements unchanged.
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self),
              let body = funcDecl.body
        else { return [] }
        
        let originalStatements = body.statements.map { $0 }
        
        // Validation 1: Must be inside a type declaration
        guard let enclosing = funcDecl.enclosingTypeDecl(in: context) else {
            context.diagnose(Diagnostic(
                node: node,
                message: WaitForInitDiagnostic.notInType(throwing: true)
            ))
            return originalStatements
        }
        
        // Validation 2: Enclosing type must conform to ThrowingInitializable
        guard funcDecl.conformsToInitializable(enclosing, with: "ThrowingInitializable") else {
            context.diagnose(Diagnostic(
                node: node,
                message: WaitForInitDiagnostic.notConforming(throwing: true)
            ))
            return originalStatements
        }
        
        let isAsync = funcDecl.isAsync
        let isThrowing = funcDecl.isThrowing
        
        // Validation 3: Check all async/throws combinations
        switch (isAsync, isThrowing) {
        case (false, false):
            // Neither async nor throws
            context.diagnose(Diagnostic(
                node: node,
                message: WaitForInitDiagnostic.notAsyncThrowing,
                fixIts: [
                    FixIt(
                        message: WaitForInitFixIt.addAsyncThrows,
                        changes: [
                            .replace(
                                oldNode: Syntax(funcDecl.signature),
                                newNode: Syntax(funcDecl.addingAsyncThrows())
                            )
                        ]
                    )
                ]
            ))
            return originalStatements
            
        case (false, true):
            // throws but not async
            context.diagnose(Diagnostic(
                node: node,
                message: WaitForInitDiagnostic.notAsync(throwing: true),
                fixIts: [
                    FixIt(
                        message: WaitForInitFixIt.addAsync,
                        changes: [
                            .replace(
                                oldNode: Syntax(funcDecl.signature),
                                newNode: Syntax(funcDecl.addingAsync())
                            )
                        ]
                    )
                ]
            ))
            return originalStatements
            
        case (true, false):
            // async but not throws — most common mistake since old code didn't need throws
            context.diagnose(Diagnostic(
                node: node,
                message: WaitForInitDiagnostic.notThrowing,
                fixIts: [
                    FixIt(
                        message: WaitForInitFixIt.addThrows,
                        changes: [
                            .replace(
                                oldNode: Syntax(funcDecl.signature),
                                newNode: Syntax(funcDecl.addingThrows())
                            )
                        ]
                    )
                ]
            ))
            return originalStatements
            
        case (true, true):
            // ✅ Correct — inject try await
            return ["try await awaitInitialized()"] + body.statements
        }
    }
}
