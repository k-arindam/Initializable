//
//  MemberAttributeMacro+Extensions.swift
//  InitializableMacros
//
//  Shared utility for detecting manually-applied `@WaitForInit` or `@WaitForThrowingInit`
//  attributes on function members when an `@AutoAwaitInit` or `@AutoAwaitThrowingInit`
//  macro is already applied to the enclosing type. Emits diagnostics with fix-its
//  to remove the redundant attribute.
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation
import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros

// MARK: - Duplicate @WaitForInit Detection

/// Extension on `MemberAttributeMacro` providing shared duplicate-detection logic.
///
/// Both ``AutoAwaitInitMacro`` and ``AutoAwaitThrowingInitMacro`` call this method
/// to detect and diagnose cases where a developer has manually applied `@WaitForInit`
/// or `@WaitForThrowingInit` to a member that would already receive it automatically.
internal extension MemberAttributeMacro {
    /// Checks whether a function member already has a manual `@WaitForInit` or
    /// `@WaitForThrowingInit` attribute, and emits a diagnostic with a fix-it if so.
    ///
    /// This prevents double-wrapping of the initialization gate call, which would cause
    /// `awaitInitialized()` to be called twice per invocation.
    ///
    /// ## Detection Logic
    /// 1. Scans the function's `attributes` list for `@WaitForInit` or `@WaitForThrowingInit`.
    /// 2. If found, emits ``AutoAwaitInitDiagnostic/manualWaitForInit(throwing:throwingWait:)``
    ///    with a fix-it that replaces the function declaration with one that has the
    ///    redundant attribute removed.
    ///
    /// - Parameters:
    ///   - funcDecl: The function declaration to inspect for duplicate attributes.
    ///   - throwing: Whether the enclosing macro is `@AutoAwaitThrowingInit` (`true`)
    ///     or `@AutoAwaitInit` (`false`). Used to generate the correct diagnostic message.
    ///   - context: The macro expansion context for emitting diagnostics.
    /// - Returns: `true` if a duplicate was found (and diagnosed), `false` otherwise.
    ///   Callers should typically return early (with `[]`) when this returns `true`.
    static func diagnoseDuplicateWaitForInit(
        on funcDecl: FunctionDeclSyntax,
        throwing: Bool,
        in context: some MacroExpansionContext
    ) -> Bool {
        let match = funcDecl.attributes.lazy.compactMap { attribute -> (syntax: AttributeListSyntax.Element, throwingWait: Bool)? in
            guard let attr = attribute.as(AttributeSyntax.self) else { return nil }
            switch attr.attributeName.trimmedDescription {
            case "WaitForThrowingInit": return (attribute, true)
            case "WaitForInit":         return (attribute, false)
            default:                    return nil
            }
        }.first
        
        guard let (existing, throwingWait) = match else { return false }
        
        // Build a new function declaration with the duplicate attribute removed
        var newAttributes = funcDecl.attributes
        newAttributes.remove(at: newAttributes.index(of: existing)!)
        var newFuncDecl = funcDecl
        newFuncDecl.attributes = newAttributes
        
        context.diagnose(Diagnostic(
            node: Syntax(existing),
            message: AutoAwaitInitDiagnostic.manualWaitForInit(throwing: throwing, throwingWait: throwingWait),
            fixIts: [
                FixIt(
                    message: AutoAwaitInitFixIt.removeWaitForInit(throwingWait: throwingWait),
                    changes: [
                        .replace(
                            oldNode: Syntax(funcDecl),
                            newNode: Syntax(newFuncDecl)
                        )
                    ]
                )
            ]
        ))
        return true
    }
    
    static func hasSkipInit(on funcDecl: FunctionDeclSyntax) -> Bool {
        funcDecl.attributes.contains {
            $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "SkipInit"
        }
    }
}
