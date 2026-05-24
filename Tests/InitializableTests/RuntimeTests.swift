import Testing
import Initializable

// MARK: - Test Helper Actors

/// A simple service actor for testing basic initialization gating.
actor SimpleService: Initializable {
    let initializationGate = InitializationGate()
    private var state: String = "pending"

    func performSetup() async {
        state = "ready"
        await markInitialized()
    }

    func getState() async -> String {
        await awaitInitialized()
        return state
    }
}

/// A counter service for testing multiple gated methods and state mutations.
actor CounterService: Initializable {
    let initializationGate = InitializationGate()
    private var counter = 0

    func initialize(with value: Int) async {
        counter = value
        await markInitialized()
    }

    func getCounter() async -> Int {
        await awaitInitialized()
        return counter
    }

    func increment() async -> Int {
        await awaitInitialized()
        counter += 1
        return counter
    }
}

// MARK: - InitializationGate Runtime Tests

@Suite("InitializationGate Runtime Behavior")
struct InitializationGateRuntimeTests {

    @Test("Gated method returns correct value after initialization")
    func gatedMethodReturnsCorrectValue() async {
        let service = SimpleService()
        await service.performSetup()
        let state = await service.getState()
        #expect(state == "ready")
    }

    @Test("Multiple calls to markInitialized are idempotent")
    func markInitializedIsIdempotent() async {
        let service = SimpleService()
        await service.performSetup()
        // Additional markInitialized calls should be safe no-ops
        await service.markInitialized()
        await service.markInitialized()
        let state = await service.getState()
        #expect(state == "ready")
    }

    @Test("awaitInitialized can be called multiple times after initialization")
    func multipleAwaitsAfterInit() async {
        let service = SimpleService()
        await service.performSetup()
        // Multiple awaits should all return immediately
        await service.awaitInitialized()
        await service.awaitInitialized()
        await service.awaitInitialized()
        let state = await service.getState()
        #expect(state == "ready")
    }

    @Test("Concurrent callers all proceed after initialization", .timeLimit(.minutes(1)))
    func concurrentCallersAllProceed() async {
        let service = SimpleService()

        await withTaskGroup(of: String.self) { group in
            // Launch concurrent waiters
            for _ in 0..<10 {
                group.addTask {
                    await service.getState()
                }
            }

            // Initialize after a short delay to let tasks enqueue at the gate
            group.addTask {
                try? await Task.sleep(for: .milliseconds(50))
                await service.performSetup()
                return "init-complete"
            }

            var stateResults: [String] = []
            for await result in group {
                if result != "init-complete" {
                    stateResults.append(result)
                }
            }

            #expect(stateResults.count == 10)
            for result in stateResults {
                #expect(result == "ready")
            }
        }
    }

    @Test("Initialize before any method calls — methods proceed immediately")
    func initializeBeforeAnyCalls() async {
        let service = CounterService()
        await service.initialize(with: 100)

        let val1 = await service.getCounter()
        #expect(val1 == 100)

        let val2 = await service.increment()
        #expect(val2 == 101)

        let val3 = await service.increment()
        #expect(val3 == 102)
    }

    @Test("Separate instances maintain independent gates")
    func separateInstancesAreIndependent() async {
        let service1 = SimpleService()
        let service2 = SimpleService()

        // Initialize only service1
        await service1.performSetup()
        let state1 = await service1.getState()
        #expect(state1 == "ready")

        // service2 is independent — must be initialized separately
        await service2.performSetup()
        let state2 = await service2.getState()
        #expect(state2 == "ready")
    }

    @Test("Task-based initialization pattern works correctly", .timeLimit(.minutes(1)))
    func taskBasedInitialization() async {
        let service = SimpleService()

        // Common pattern: spawn a background Task to perform async init
        Task {
            try? await Task.sleep(for: .milliseconds(20))
            await service.performSetup()
        }

        // getState suspends at the gate until the background Task completes setup
        let state = await service.getState()
        #expect(state == "ready")
    }

    @Test("Gated method sees state set during initialization", .timeLimit(.minutes(1)))
    func gatedMethodSeesInitializedState() async throws {
        let service = CounterService()

        // Start a task that calls a gated method — it will suspend at the gate
        let task = Task {
            await service.getCounter()
        }

        // Give the task time to enqueue and hit the gate
        try await Task.sleep(for: .milliseconds(100))

        // Initialize with a specific value
        await service.initialize(with: 99)

        // The gated task must return the initialized value, not the default (0)
        let result = await task.value
        #expect(result == 99)
    }

    @Test("Multiple different gated methods complete after initialization", .timeLimit(.minutes(1)))
    func multipleGatedMethodsComplete() async {
        let service = CounterService()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // This will gate, then read the counter
                let val = await service.getCounter()
                #expect(val == 42)
            }

            group.addTask {
                try? await Task.sleep(for: .milliseconds(50))
                await service.initialize(with: 42)
            }
        }
    }

    @Test("InitializationGate can be constructed independently")
    func gateConstruction() {
        // Verify the public init is accessible
        let gate = InitializationGate()
        _ = gate
    }

    @Test("Sequential initialize-then-read pattern")
    func sequentialPattern() async {
        let service = CounterService()
        await service.initialize(with: 7)

        // Multiple sequential reads all see the initialized value
        for _ in 0..<5 {
            let val = await service.getCounter()
            #expect(val == 7)
        }
    }

    @Test("Increment after initialization mutates correctly")
    func incrementAfterInit() async {
        let service = CounterService()
        await service.initialize(with: 0)

        var expected = 0
        for _ in 0..<10 {
            expected += 1
            let val = await service.increment()
            #expect(val == expected)
        }
    }

    @Test("Mixed reads and writes after initialization")
    func mixedReadsAndWrites() async {
        let service = CounterService()
        await service.initialize(with: 10)

        let read1 = await service.getCounter()
        #expect(read1 == 10)

        let inc1 = await service.increment()
        #expect(inc1 == 11)

        let read2 = await service.getCounter()
        #expect(read2 == 11)

        let inc2 = await service.increment()
        #expect(inc2 == 12)

        let read3 = await service.getCounter()
        #expect(read3 == 12)
    }
}

// MARK: - Initializable Protocol Conformance Tests

@Suite("Initializable Protocol Conformance")
struct InitializableConformanceTests {

    @Test("Conforming actor exposes initializationGate property")
    func conformingActorExposesGate() async {
        let service = SimpleService()
        // Access the gate to verify the protocol requirement is satisfied
        let gate = await service.initializationGate
        _ = gate
    }

    @Test("markInitialized and awaitInitialized are accessible on conforming type")
    func protocolMethodsAccessible() async {
        let service = SimpleService()
        // Both protocol extension methods should be callable
        await service.markInitialized()
        await service.awaitInitialized()
    }

    @Test("awaitInitialized returns immediately when already initialized via protocol method")
    func awaitInitializedReturnsImmediatelyWhenReady() async {
        let service = SimpleService()
        // Use protocol method directly
        await service.markInitialized()
        // Should not hang — gate is already open
        await service.awaitInitialized()
    }

    @Test("Multiple conforming actors operate independently")
    func multipleConformingActorsIndependent() async {
        let s1 = SimpleService()
        let s2 = CounterService()

        await s1.performSetup()
        await s2.initialize(with: 5)

        let state = await s1.getState()
        #expect(state == "ready")

        let counter = await s2.getCounter()
        #expect(counter == 5)
    }
}
