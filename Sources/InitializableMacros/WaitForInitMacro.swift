//
//  WaitForInitMacro.swift
//  InitializableMacros
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation
import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros

// Prepends `await awaitInitialized()` to the function body
public struct WaitForInitMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self),
              let body = funcDecl.body
        else { return [] }
        
        let originalStatements = body.statements.map { $0 }
        
        guard let enclosing = funcDecl.enclosingTypeDecl(in: context) else {
            context.diagnose(Diagnostic(
                node: node,
                message: WaitForInitDiagnostic.notInType(throwing: false)
            ))
            return originalStatements
        }
        
        guard funcDecl.conformsToInitializable(enclosing, with: "Initializable") else {
            context.diagnose(Diagnostic(
                node: node,
                message: WaitForInitDiagnostic.notConforming(throwing: false)
            ))
            return originalStatements
        }
        
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
        
        return ["await awaitInitialized()"] + body.statements
    }
}

public struct WaitForThrowingInitMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self),
              let body = funcDecl.body
        else { return [] }
        
        let originalStatements = body.statements.map { $0 }
        
        guard let enclosing = funcDecl.enclosingTypeDecl(in: context) else {
            context.diagnose(Diagnostic(
                node: node,
                message: WaitForInitDiagnostic.notInType(throwing: true)
            ))
            return originalStatements
        }
        
        guard funcDecl.conformsToInitializable(enclosing, with: "ThrowingInitializable") else {
            context.diagnose(Diagnostic(
                node: node,
                message: WaitForInitDiagnostic.notConforming(throwing: true)
            ))
            return originalStatements
        }
        
        let isAsync = funcDecl.isAsync
        let isThrowing = funcDecl.isThrowing
        
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
