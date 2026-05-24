//
//  FunctionDeclSyntax+Extensions.swift
//  InitializableMacros
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation
import SwiftSyntax

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
            specifiers.asyncSpecifier = .keyword(.async)
        }
        if specifiers.throwsClause == nil {
            specifiers.throwsClause = ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
        }
        var newSignature = signature
        newSignature.effectSpecifiers = specifiers
        return newSignature
    }
    
    func addingThrows() -> FunctionSignatureSyntax {
        var specifiers = signature.effectSpecifiers ?? FunctionEffectSpecifiersSyntax()
        if specifiers.throwsClause == nil {
            specifiers.throwsClause = ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
        }
        var newSignature = signature
        newSignature.effectSpecifiers = specifiers
        return newSignature
    }
    
    func addingAsync() -> FunctionSignatureSyntax {
        var specifiers = signature.effectSpecifiers ?? FunctionEffectSpecifiersSyntax()
        if specifiers.asyncSpecifier == nil {
            specifiers.asyncSpecifier = .keyword(.async)
        }
        var newSignature = signature
        newSignature.effectSpecifiers = specifiers
        return newSignature
    }
}
