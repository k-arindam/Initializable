//
//  ContentView.swift
//  InitializableExample
//
//  Created by Arindam Karmakar on 24/05/26.
//

import SwiftUI
import Initializable

@AutoAwaitInit
internal final class Manager: Initializable {
    let initializationGate = InitializationGate()
    
    @WaitForInit
    func method1() async throws {}
    
    func method2() async throws {}
}

struct ContentView: View {
    let manager = Manager()
    var body: some View {
        VStack {
            Button("Initialize Manager") {
                Task { await manager.markInitialized() }
            }
            Button("Start method calls") {
                debugPrint("----->>> Starting method calls")
                Task { @concurrent in
                    await withThrowingTaskGroup(of: Void.self) { group in
                        for i in 0..<1_000 {
                            group.addTask {
                                if i.isMultiple(of: 2) {
                                    try await manager.method1()
                                } else {
                                    try await manager.method2()
                                }
                                debugPrint("----->>> Completed task with index: \(i)")
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .buttonStyle(.glassProminent)
    }
}

#Preview {
    ContentView()
}
