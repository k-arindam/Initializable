//
//  MemberAttributeMacro+Extensions.swift
//  Initializable
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation
import SwiftSyntax
import SwiftDiagnostics
import SwiftSyntaxMacros

internal extension MemberAttributeMacro {
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
}
