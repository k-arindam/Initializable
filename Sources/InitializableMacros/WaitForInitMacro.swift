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

// Diagnostic definitions
enum WaitForInitDiagnostic: DiagnosticMessage {
    case appliedToSyncMethod
    
    var message: String {
        switch self {
        case .appliedToSyncMethod:
            "@WaitForInit can only be applied to async functions"
        }
    }
    
    var diagnosticID: MessageID {
        MessageID(domain: "InitializableMacros", id: "\(self)")
    }
    
    var severity: DiagnosticSeverity { .error }
}

// Fix-it to add async
enum WaitForInitFixIt: FixItMessage {
    case addAsync
    
    var message: String {
        switch self {
        case .addAsync: "Add 'async'"
        }
    }
    
    var fixItID: MessageID {
        MessageID(domain: "InitializableMacros", id: "\(self)")
    }
}

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
        
        // Sync method — emit diagnostic + fix-it instead of expanding
        guard funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil else {
            let funcKeyword = funcDecl.funcKeyword
            
            // Build fix-it: insert `async` before the function name
            let newEffectSpecifiers = FunctionEffectSpecifiersSyntax(
                asyncSpecifier: .keyword(.async)
            )
            var newSignature = funcDecl.signature
            newSignature.effectSpecifiers = newEffectSpecifiers
            
            var newFuncDecl = funcDecl
            newFuncDecl.signature = newSignature
            
            context.diagnose(Diagnostic(
                node: node,
                message: WaitForInitDiagnostic.appliedToSyncMethod,
                fixIts: [
                    FixIt(
                        message: WaitForInitFixIt.addAsync,
                        changes: [
                            .replace(
                                oldNode: Syntax(funcDecl.signature),
                                newNode: Syntax(newSignature)
                            )
                        ]
                    )
                ]
            ))
            return body.statements.map { $0 }
        }
        
        return ["await awaitInitialized()"] + body.statements
    }
}
