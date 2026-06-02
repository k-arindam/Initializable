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
    
    func method(_ i: Int) async { debugPrint("----->>> Completed manager 1 task with index: \(i)") }
}

internal final class Manager2: Initializable {
    let gate = InitializationGate()
    
    @WaitForInit
    func method(_ i: Int) async { debugPrint("----->>> Completed manager 2 task with index: \(i)") }
}

@AutoAwaitThrowingInit
internal final class Manager3: ThrowingInitializable {
    let gate = ThrowingInitializationGate()
    
    func method(_ i: Int) async throws { debugPrint("----->>> Completed manager 3 task with index: \(i)") }
}

internal final class Manager4: ThrowingInitializable {
    let gate = ThrowingInitializationGate()
    
    @WaitForThrowingInit
    func method(_ i: Int) async throws { debugPrint("----->>> Completed manager 4 task with index: \(i)") }
}

@AutoAwaitInit
internal final class Manager5: Initializable {
    let gate = InitializationGate()
    
    @SkipInit
    func method(_ i: Int) async { debugPrint("----->>> Completed manager 5 task with index: \(i)") }
}

struct ContentView: View {
    let manager1 = Manager1()
    let manager2 = Manager2()
    let manager3 = Manager3()
    let manager4 = Manager4()
    let manager5 = Manager5()
    
    var body: some View {
        VStack {
            Button("Initialize Manager") {
                debugPrint("----->>> Starting initialization")
                
                Task {
                    await manager1.markInitialized()
                    await manager2.markInitialized()
                    await manager3.markInitialized()
                    await manager4.markInitialized()
                    await manager5.markInitialized()
                }
            }
            
            Button("Start method calls") {
                debugPrint("----->>> Starting method calls")
                
                Task { @concurrent in
                    await withThrowingTaskGroup(of: Void.self) { group in
                        for i in 0..<1_000 {
                            group.addTask { await manager1.method(i) }
                            group.addTask { await manager2.method(i) }
                            group.addTask { try await manager3.method(i) }
                            group.addTask { try await manager4.method(i) }
                            group.addTask { await manager5.method(i) }
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
