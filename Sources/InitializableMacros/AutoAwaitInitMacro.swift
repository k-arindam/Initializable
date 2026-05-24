//
//  AutoAwaitInitMacro.swift
//  InitializableMacros
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation
import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros

// Stamps @WaitForInit onto every async method in the conforming actor
public struct AutoAwaitInitMacro: MemberAttributeMacro {
    // Methods that are part of the protocol itself — must not be wrapped
    static let excluded: Set<String> = ["markInitialized", "markFailed", "awaitInitialized"]
    
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              !excluded.contains(funcDecl.name.text)
        else { return [] }
        
        let isAsync = funcDecl.isAsync
        let isThrowing = funcDecl.isThrowing
        
        // Only stamp @WaitForInit on async throws methods — skip everything else
        // @WaitForInit itself will emit proper diagnostics when applied manually
        // to wrong signatures, but here we only auto-apply when correct
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
        
        return ["@WaitForInit"]
    }
}
