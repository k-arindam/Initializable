//
//  FunctionDeclSyntax+Extensions.swift
//  InitializableMacros
//
//  Syntax tree helpers on `FunctionDeclSyntax` used by the macro implementations
//  to inspect function signatures, add effect specifiers, check protocol conformance,
//  and resolve enclosing type declarations from lexical context.
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - FunctionDeclSyntax Helpers

/// Internal extensions on `FunctionDeclSyntax` providing utilities for the macro implementations.
///
/// These helpers abstract common AST inspection patterns used throughout the
/// `@WaitForInit`, `@WaitForThrowingInit`, `@AutoAwaitInit`, and `@AutoAwaitThrowingInit` macros.
internal extension FunctionDeclSyntax {

    // MARK: Effect Specifier Inspection

    /// Whether the function signature includes the `async` keyword.
    ///
    /// Checks for the presence of `effectSpecifiers.asyncSpecifier` in the function signature.
    ///
    /// - Returns: `true` if the function is declared with `async`, `false` otherwise.
    var isAsync: Bool {
        signature.effectSpecifiers?.asyncSpecifier != nil
    }
    
    /// Whether the function signature includes a `throws` clause.
    ///
    /// Checks for the presence of `effectSpecifiers.throwsClause` in the function signature.
    /// This covers both plain `throws` and typed throws (e.g., `throws(MyError)`).
    ///
    /// - Returns: `true` if the function is declared with `throws`, `false` otherwise.
    var isThrowing: Bool {
        signature.effectSpecifiers?.throwsClause != nil
    }
    
    // MARK: Signature Mutation

    /// Returns a copy of the function signature with both `async` and `throws` added.
    ///
    /// If either specifier is already present, it is preserved (not duplicated).
    /// Used by fix-it suggestions for ``WaitForInitDiagnostic/notAsyncThrowing``.
    ///
    /// - Returns: A new `FunctionSignatureSyntax` with both effect specifiers set.
    func addingAsyncThrows() -> FunctionSignatureSyntax {
        var specifiers = signature.effectSpecifiers ?? FunctionEffectSpecifiersSyntax()
        if specifiers.asyncSpecifier == nil {
            specifiers.asyncSpecifier = .keyword(.async, trailingTrivia: .space)
        }
        if specifiers.throwsClause == nil {
            specifiers.throwsClause = ThrowsClauseSyntax(throwsSpecifier:
                    .keyword(.throws, trailingTrivia: .space)
            )
        }
        var newSignature = signature
        newSignature.effectSpecifiers = specifiers
        return newSignature
    }
    
    /// Returns a copy of the function signature with `throws` added.
    ///
    /// If `throws` is already present, returns the original signature unchanged.
    /// Used by fix-it suggestions for ``WaitForInitDiagnostic/notThrowing``.
    ///
    /// - Returns: A new `FunctionSignatureSyntax` with the `throws` clause set.
    func addingThrows() -> FunctionSignatureSyntax {
        var specifiers = signature.effectSpecifiers ?? FunctionEffectSpecifiersSyntax()
        if specifiers.throwsClause == nil {
            specifiers.throwsClause = ThrowsClauseSyntax(throwsSpecifier:
                    .keyword(.throws, trailingTrivia: .space)
            )
        }
        var newSignature = signature
        newSignature.effectSpecifiers = specifiers
        return newSignature
    }
    
    /// Returns a copy of the function signature with `async` added.
    ///
    /// If `async` is already present, returns the original signature unchanged.
    /// Used by fix-it suggestions for ``WaitForInitDiagnostic/notAsync(throwing:)``.
    ///
    /// - Returns: A new `FunctionSignatureSyntax` with the `async` specifier set.
    func addingAsync() -> FunctionSignatureSyntax {
        var specifiers = signature.effectSpecifiers ?? FunctionEffectSpecifiersSyntax()
        if specifiers.asyncSpecifier == nil {
            specifiers.asyncSpecifier = .keyword(.async, trailingTrivia: .space)
        }
        var newSignature = signature
        newSignature.effectSpecifiers = specifiers
        return newSignature
    }
    
    // MARK: Conformance Checking

    /// Checks whether the given type declaration's inheritance clause contains the specified protocol.
    ///
    /// Performs a **string-based** comparison on the trimmed type description,
    /// matching against protocol names like `"Initializable"` or `"ThrowingInitializable"`.
    ///
    /// - Parameters:
    ///   - declaration: The `DeclGroupSyntax` (actor, class, struct) to inspect.
    ///   - desc: The protocol name to search for (e.g., `"Initializable"`).
    /// - Returns: `true` if the inheritance clause contains a type matching `desc`.
    func conformsToInitializable(_ declaration: some DeclGroupSyntax, with desc: String) -> Bool {
        declaration.inheritanceClause?.inheritedTypes.contains {
            $0.type.trimmedDescription == desc
        } ?? false
    }
    
    // MARK: Lexical Context Resolution

    /// Walks the macro expansion's lexical context to find the nearest enclosing type declaration.
    ///
    /// Searches through the `context.lexicalContext` stack for the first occurrence of
    /// an `ActorDeclSyntax`, `ClassDeclSyntax`, or `StructDeclSyntax`. This is used by
    /// body macros (`@WaitForInit`, `@WaitForThrowingInit`) to locate the type they are
    /// applied within, since body macros don't receive the enclosing type as a parameter.
    ///
    /// - Parameter context: The macro expansion context providing the lexical scope chain.
    /// - Returns: The nearest enclosing `DeclGroupSyntax`, or `nil` if the function is a free function.
    func enclosingTypeDecl(
        in context: some MacroExpansionContext
    ) -> (any DeclGroupSyntax)? {
        for syntax in context.lexicalContext {
            if let decl = syntax.as(ActorDeclSyntax.self)  { return decl }
            if let decl = syntax.as(ClassDeclSyntax.self)  { return decl }
            if let decl = syntax.as(StructDeclSyntax.self) { return decl }
        }
        return nil
    }
}
