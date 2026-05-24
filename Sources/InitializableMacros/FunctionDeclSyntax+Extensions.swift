//
//  FunctionDeclSyntax+Extensions.swift
//  InitializableMacros
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - Helpers

internal extension FunctionDeclSyntax {
    var isAsync: Bool {
        signature.effectSpecifiers?.asyncSpecifier != nil
    }
    
    var isThrowing: Bool {
        signature.effectSpecifiers?.throwsClause != nil
    }
    
    /// Returns a copy of the signature with both async and throws added
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
    
    func addingAsync() -> FunctionSignatureSyntax {
        var specifiers = signature.effectSpecifiers ?? FunctionEffectSpecifiersSyntax()
        if specifiers.asyncSpecifier == nil {
            specifiers.asyncSpecifier = .keyword(.async, trailingTrivia: .space)
        }
        var newSignature = signature
        newSignature.effectSpecifiers = specifiers
        return newSignature
    }
    
    /// Checks the inheritance clause of any type declaration for Initializable conformance
    func conformsToInitializable(_ declaration: some DeclGroupSyntax, with desc: String) -> Bool {
        declaration.inheritanceClause?.inheritedTypes.contains {
            $0.type.trimmedDescription == desc
        } ?? false
    }
    
    /// Walks lexicalContext to find the nearest enclosing type declaration
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
