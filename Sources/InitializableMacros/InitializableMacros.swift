//
//  InitializableMacros.swift
//  InitializableMacros
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation
import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct InitializableMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        AutoAwaitInitMacro.self,
        WaitForInitMacro.self,
    ]
}
