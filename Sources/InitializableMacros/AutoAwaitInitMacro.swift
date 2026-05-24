//
//  AutoAwaitInitMacro.swift
//  InitializableMacros
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation
import SwiftSyntax
import SwiftSyntaxMacros

// Stamps @WaitForInit onto every async method in the conforming actor
public struct AutoAwaitInitMacro: MemberAttributeMacro {
    // Methods that are part of the protocol itself — must not be wrapped
    static let excluded: Set<String> = ["markInitialized", "awaitInitialized"]
    
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let funcDecl = member.as(FunctionDeclSyntax.self),
              !excluded.contains(funcDecl.name.text),
              // Only async functions can suspend for init
              funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        else { return [] }
        
        return ["@WaitForInit"]
    }
}
