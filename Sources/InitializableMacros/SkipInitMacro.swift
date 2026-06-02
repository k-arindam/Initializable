//
//  SkipInitMacro.swift
//  InitializableMacros
//
//  Peer macro implementation that acts as a marker attribute for opting
//  individual methods out of automatic `@WaitForInit` / `@WaitForThrowingInit`
//  stamping by `@AutoAwaitInit` and `@AutoAwaitThrowingInit`. This macro does
//  not synthesize any peer declarations — it exists solely so the
//  member-attribute macros can detect it via `hasSkipInit(on:)`.
//
//  Created by Arindam Karmakar on 02/06/26.
//

import Foundation
import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros

// MARK: - SkipInitMacro (Peer Macro)

/// A peer macro that marks an `async` method to be excluded from automatic
/// initialization gating by ``AutoAwaitInitMacro`` or ``AutoAwaitThrowingInitMacro``.
///
/// `@SkipInit` produces **no peer declarations**. Its sole purpose is to act as a
/// syntactic marker that the member-attribute macros check via
/// ``MemberAttributeMacro/hasSkipInit(on:)`` before stamping `@WaitForInit`
/// or `@WaitForThrowingInit`.
///
/// ## Expansion Logic
/// The macro's `expansion(of:providingPeersOf:in:)` always returns an empty array.
/// Before doing so, it performs two validation checks:
///
/// 1. **Async requirement**: The decorated function must be `async`. Synchronous
///    functions are never stamped by `@AutoAwaitInit`/`@AutoAwaitThrowingInit`, so
///    `@SkipInit` would be meaningless.
///    → Emits ``SkipInitDiagnostic/notAsync`` with a fix-it to remove `@SkipInit`.
///
/// 2. **Enclosing macro requirement**: The enclosing type must have `@AutoAwaitInit`
///    or `@AutoAwaitThrowingInit`. Without one of these, there is no automatic
///    stamping to opt out of.
///    → Emits ``SkipInitDiagnostic/notInsideAutoAwaitInit`` with a fix-it to remove `@SkipInit`.
///
/// - SeeAlso: ``AutoAwaitInitMacro``, ``AutoAwaitThrowingInitMacro``, ``SkipInitDiagnostic``
public struct SkipInitMacro: PeerMacro {
    /// Validates the `@SkipInit` attribute and returns an empty peer declaration list.
    ///
    /// This method performs validation checks and emits diagnostics for invalid usage,
    /// but never synthesizes any declarations. The attribute serves as a compile-time
    /// marker that is consumed by ``AutoAwaitInitMacro`` and ``AutoAwaitThrowingInitMacro``.
    ///
    /// - Parameters:
    ///   - node: The `@SkipInit` attribute syntax node.
    ///   - declaration: The declaration this macro is attached to (expected to be a function).
    ///   - context: The macro expansion context for emitting diagnostics and inspecting lexical scope.
    /// - Returns: An empty array — this macro never produces peer declarations.
    /// - Throws: Never throws; diagnostics are emitted via `context.diagnose()`.
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Only function declarations are valid targets for @SkipInit.
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else { return [] }
        
        // Validation 1: The function must be async.
        // Synchronous functions are never wrapped by @AutoAwaitInit or
        // @AutoAwaitThrowingInit, so @SkipInit on them is a no-op and likely a mistake.
        if !funcDecl.isAsync {
            var newAttributes = funcDecl.attributes
            if let existing = newAttributes.first(where: {
                $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "SkipInit"
            }) {
                newAttributes.remove(at: newAttributes.index(of: existing)!)
            }
            var newFuncDecl = funcDecl
            newFuncDecl.attributes = newAttributes
            
            context.diagnose(Diagnostic(
                node: node,
                message: SkipInitDiagnostic.notAsync,
                fixIts: [
                    FixIt(
                        message: SkipInitFixIt.removeSkipInit,
                        changes: [
                            .replace(
                                oldNode: Syntax(funcDecl),
                                newNode: Syntax(newFuncDecl)
                            )
                        ]
                    )
                ]
            ))
            return []
        }
        
        // The set of member-attribute macro names that perform automatic stamping.
        let autoAwaitNames: Set<String> = ["AutoAwaitInit", "AutoAwaitThrowingInit"]
        
        // Validation 2: The enclosing type must have @AutoAwaitInit or @AutoAwaitThrowingInit.
        // Walk the lexical context to find a type declaration carrying one of these attributes.
        let enclosingHasAutoAwait = context.lexicalContext.contains { syntax in
            guard let typeDecl = syntax.asProtocol(WithAttributesSyntax.self) else { return false }
            return typeDecl.attributes.contains {
                guard let attr = $0.as(AttributeSyntax.self) else { return false }
                return autoAwaitNames.contains(attr.attributeName.trimmedDescription)
            }
        }
        
        // If no enclosing @AutoAwait* macro is found, @SkipInit has nothing to skip.
        guard enclosingHasAutoAwait else {
            var newAttributes = funcDecl.attributes
            if let existing = newAttributes.first(where: {
                $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "SkipInit"
            }) {
                newAttributes.remove(at: newAttributes.index(of: existing)!)
            }
            
            var newFuncDecl = funcDecl
            newFuncDecl.attributes = newAttributes
            
            context.diagnose(Diagnostic(
                node: node,
                message: SkipInitDiagnostic.notInsideAutoAwaitInit,
                fixIts: [
                    FixIt(
                        message: SkipInitFixIt.removeSkipInit,
                        changes: [
                            .replace(
                                oldNode: Syntax(funcDecl),
                                newNode: Syntax(newFuncDecl)
                            )
                        ]
                    )
                ]
            ))
            return []
        }
        
        // ✅ All validations passed — the marker is valid, return no peers.
        return []
    }
}
