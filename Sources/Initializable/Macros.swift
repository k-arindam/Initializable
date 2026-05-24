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

@attached(memberAttribute)
public macro AutoAwaitThrowingInit() = #externalMacro(
    module: "InitializableMacros",
    type: "AutoAwaitThrowingInitMacro"
)

@attached(body)
public macro WaitForInit() = #externalMacro(
    module: "InitializableMacros",
    type: "WaitForInitMacro"
)

@attached(body)
public macro WaitForThrowingInit() = #externalMacro(
    module: "InitializableMacros",
    type: "WaitForThrowingInitMacro"
)
