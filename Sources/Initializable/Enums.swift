//
//  Enums.swift
//  Initializable
//
//  Created by Arindam Karmakar on 24/05/26.
//

import Foundation

internal enum InitializationState {
    case pending
    case initialized
    case failed(any Error)
}

internal enum GateType {
    case throwable
    case nonThrowable
}
