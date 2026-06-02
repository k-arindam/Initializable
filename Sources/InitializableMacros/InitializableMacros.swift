//
//  InitializableMacros.swift
//  InitializableMacros
//
//  The compiler plugin entry point for the Initializable macro package.
//  Registers all macro implementations with the Swift compiler so they can
//  be resolved from `#externalMacro` declarations in the `Initializable` module.
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation
import SwiftSyntaxMacros
import SwiftCompilerPlugin

/// The main compiler plugin that provides macro implementations to the Swift compiler.
///
/// This plugin registers five macros:
/// - ``AutoAwaitInitMacro``: Member-attribute macro for non-throwing initialization gating.
/// - ``AutoAwaitThrowingInitMacro``: Member-attribute macro for throwing initialization gating.
/// - ``WaitForInitMacro``: Body macro that injects `await awaitInitialized()`.
/// - ``WaitForThrowingInitMacro``: Body macro that injects `try await awaitInitialized()`.
/// - ``SkipInitMacro``: Peer macro that opts individual methods out of automatic stamping.
///
/// - SeeAlso: The corresponding `#externalMacro` declarations in `Macros.swift`.
@main
struct InitializableMacrosPlugin: CompilerPlugin {
    /// The list of macro types provided by this plugin, resolved by name at compile time.
    let providingMacros: [any Macro.Type] = [
        AutoAwaitInitMacro.self,
        AutoAwaitThrowingInitMacro.self,
        WaitForInitMacro.self,
        WaitForThrowingInitMacro.self,
        SkipInitMacro.self
    ]
}
