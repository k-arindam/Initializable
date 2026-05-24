//
//  ContentView.swift
//  InitializableExample
//
//  Created by Arindam Karmakar on 24/05/26.
//

import SwiftUI
import Initializable

@AutoAwaitInit
internal final class Manager1: Initializable {
    let gate = InitializationGate()
    
    func method() async {}
}

internal final class Manager2: Initializable {
    let gate = InitializationGate()
    
    @WaitForInit
    func method() async {}
}

@AutoAwaitThrowingInit
internal final class Manager3: ThrowingInitializable {
    let gate = ThrowingInitializationGate()
    
    func method() async throws {}
}

internal final class Manager4: ThrowingInitializable {
    let gate = ThrowingInitializationGate()
    
    @WaitForThrowingInit
    func method() async throws {}
}

struct ContentView: View {
    let manager1 = Manager1()
    let manager2 = Manager2()
    let manager3 = Manager3()
    let manager4 = Manager4()
    
    var body: some View {
        VStack {
            Button("Initialize Manager") {
                Task {
                    await manager1.markInitialized()
                    await manager2.markInitialized()
                    await manager3.markInitialized()
                    await manager4.markInitialized()
                }
            }
            Button("Start method calls") {
                debugPrint("----->>> Starting method calls")
                Task { @concurrent in
                    await withThrowingTaskGroup(of: Void.self) { group in
                        for i in 0..<1_000 {
                            group.addTask {
                                await manager1.method()
                                await manager2.method()
                                try await manager3.method()
                                try await manager4.method()
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
