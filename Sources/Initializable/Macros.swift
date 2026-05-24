//
//  Macros.swift
//  Initializable
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation

@attached(memberAttribute)
public macro AutoAwaitInit() = #externalMacro(
    module: "InitializableMacros",
    type: "AutoAwaitInitMacro"
)

@attached(body)
public macro WaitForInit() = #externalMacro(
    module: "InitializableMacros",
    type: "WaitForInitMacro"
)
