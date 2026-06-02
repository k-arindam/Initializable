//
//  SkipInitMacro.swift
//  InitializableMacros
//
//  Created by Arindam Karmakar on 02/06/26.
//

import Foundation
import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros

public struct SkipInitMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else { return [] }
        
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
        
        let autoAwaitNames: Set<String> = ["AutoAwaitInit", "AutoAwaitThrowingInit"]
        
        let enclosingHasAutoAwait = context.lexicalContext.contains { syntax in
            guard let typeDecl = syntax.asProtocol(WithAttributesSyntax.self) else { return false }
            return typeDecl.attributes.contains {
                guard let attr = $0.as(AttributeSyntax.self) else { return false }
                return autoAwaitNames.contains(attr.attributeName.trimmedDescription)
            }
        }
        
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
        
        return []
    }
}
