//
//  AutoAwaitInitMacro.swift
//  InitializableMacros
//
//  Member-attribute macro implementations that automatically stamp
//  `@WaitForInit` or `@WaitForThrowingInit` onto qualifying methods
//  within a type declaration. These macros eliminate the need to manually
//  annotate each method with the corresponding body macro.
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation
import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros

// MARK: - AutoAwaitInitMacro (Non-Throwing)

/// A member-attribute macro that stamps `@WaitForInit` on every qualifying `async` method.
///
/// This macro is attached to a type declaration (actor, class, or struct) and iterates
/// over its function members. For each `async` method that is not in the exclusion list,
/// it emits `@WaitForInit` as a synthesized attribute.
///
/// ## Expansion Logic
/// 1. **Guard**: Only processes `FunctionDeclSyntax` members — skips properties, inits, etc.
/// 2. **Exclude**: Skips ``excluded`` protocol methods (`markInitialized`, `awaitInitialized`).
/// 3. **Conformance**: Verifies the enclosing type conforms to `Initializable`.
///    Emits ``AutoAwaitInitDiagnostic/notConforming(throwing:)`` if not.
/// 4. **Duplicate check**: Detects manually-applied `@WaitForInit` or `@WaitForThrowingInit`
///    and emits ``AutoAwaitInitDiagnostic/manualWaitForInit(throwing:throwingWait:)`` with
///    a fix-it to remove the redundant attribute.
/// 5. **Stamp**: Returns `["@WaitForInit"]` for `async` methods.
///
/// - SeeAlso: ``AutoAwaitThrowingInitMacro``, ``WaitForInitMacro``
public struct AutoAwaitInitMacro: MemberAttributeMacro {
    /// Protocol methods that must not receive `@WaitForInit` to avoid infinite recursion.
    ///
    /// These are the methods defined by the `Initializable` protocol itself.
    static let excluded: Set<String> = ["markInitialized", "awaitInitialized"]
    
    /// Provides attributes for a single member of the attached type declaration.
    ///
    /// Called once per member by the compiler. Returns `["@WaitForInit"]` for qualifying
    /// `async` methods, or an empty array for non-qualifying members.
    ///
    /// - Parameters:
    ///   - node: The `@AutoAwaitInit` attribute syntax node.
    ///   - declaration: The type declaration (actor, class, struct) the macro is attached to.
    ///   - member: The individual member being evaluated.
    ///   - context: The macro expansion context for emitting diagnostics.
    /// - Returns: An array of `AttributeSyntax` to attach to the member.
    /// - Throws: Never throws; diagnostics are emitted via `context.diagnose()`.
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              !excluded.contains(funcDecl.name.text)
        else { return [] }
        
        guard funcDecl.conformsToInitializable(declaration, with: "Initializable") else {
            context.diagnose(Diagnostic(
                node: node,
                message: AutoAwaitInitDiagnostic.notConforming(throwing: false)
            ))
            return []
        }
        
        if diagnoseDuplicateWaitForInit(
            on: funcDecl,
            throwing: false,
            in: context
        ), !funcDecl.isAsync { return [] }
        
        return ["@WaitForInit"]
    }
}

// MARK: - AutoAwaitThrowingInitMacro

/// A member-attribute macro that stamps `@WaitForThrowingInit` on every qualifying
/// `async throws` method.
///
/// Similar to ``AutoAwaitInitMacro``, but targets types conforming to `ThrowingInitializable`
/// and only stamps methods that are both `async` **and** `throws`.
///
/// ## Expansion Logic
/// 1. **Guard**: Only processes `FunctionDeclSyntax` members.
/// 2. **Exclude**: Skips ``excluded`` protocol methods (`markInitialized`, `markFailed`, `awaitInitialized`).
/// 3. **Conformance**: Verifies the type conforms to `ThrowingInitializable`.
/// 4. **Duplicate check**: Detects manually-applied `@WaitForInit`/`@WaitForThrowingInit`.
/// 5. **Signature check**:
///    - `async throws` → stamps `@WaitForThrowingInit` ✅
///    - `async` only → emits ``WaitForInitDiagnostic/notThrowing`` with a fix-it to add `throws`.
///    - `throws` only or sync → silently skipped (no diagnostic).
///
/// - SeeAlso: ``AutoAwaitInitMacro``, ``WaitForThrowingInitMacro``
public struct AutoAwaitThrowingInitMacro: MemberAttributeMacro {
    /// Protocol methods that must not receive `@WaitForThrowingInit`.
    ///
    /// These are the methods defined by the `ThrowingInitializable` protocol itself.
    static let excluded: Set<String> = ["markInitialized", "markFailed", "awaitInitialized"]
    
    /// Provides attributes for a single member of the attached type declaration.
    ///
    /// Called once per member by the compiler. Returns `["@WaitForThrowingInit"]` for qualifying
    /// `async throws` methods, or an empty array otherwise.
    ///
    /// - Parameters:
    ///   - node: The `@AutoAwaitThrowingInit` attribute syntax node.
    ///   - declaration: The type declaration the macro is attached to.
    ///   - member: The individual member being evaluated.
    ///   - context: The macro expansion context for emitting diagnostics.
    /// - Returns: An array of `AttributeSyntax` to attach to the member.
    /// - Throws: Never throws; diagnostics are emitted via `context.diagnose()`.
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              !excluded.contains(funcDecl.name.text)
        else { return [] }
        
        guard funcDecl.conformsToInitializable(declaration, with: "ThrowingInitializable") else {
            context.diagnose(Diagnostic(
                node: node,
                message: AutoAwaitInitDiagnostic.notConforming(throwing: true)
            ))
            return []
        }
        
        if diagnoseDuplicateWaitForInit(
            on: funcDecl,
            throwing: true,
            in: context
        ) { return [] }
        
        let isAsync = funcDecl.isAsync
        let isThrowing = funcDecl.isThrowing
        
        // Only stamp @WaitForThrowingInit on async throws methods — skip everything else.
        // @WaitForThrowingInit itself will emit proper diagnostics when applied manually
        // to wrong signatures, but here we only auto-apply when correct.
        guard isAsync && isThrowing else {
            if isAsync && !isThrowing {
                context.diagnose(Diagnostic(
                    node: Syntax(funcDecl.funcKeyword),
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
            }
            return []
        }
        
        return ["@WaitForThrowingInit"]
    }
}
