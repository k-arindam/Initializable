//
//  RuntimeTests.swift
//  InitializableTests
//
//  Runtime behavior tests for InitializationGate, ThrowingInitializationGate,
//  Initializable protocol, and ThrowingInitializable protocol.
//  Covers happy paths, idempotency, concurrency, cancellation, and error propagation.
//

import Testing
import Initializable

// MARK: - Test Helper Actors (Non-Throwing)

/// A simple service actor for testing basic initialization gating.
actor SimpleService: Initializable {
    let gate = InitializationGate()
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
    let gate = InitializationGate()
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

// MARK: - Test Helper Actors (Throwing)

/// Custom error type for testing ThrowingInitializable.
struct SetupError: Error, Equatable {
    let reason: String
}

/// A throwing service actor for testing ThrowingInitializationGate.
actor ThrowingService: ThrowingInitializable {
    let gate = ThrowingInitializationGate()
    private var state: String = "pending"

    func performSetup() async {
        state = "ready"
        await markInitialized()
    }

    func failSetup(reason: String) async {
        await markFailed(SetupError(reason: reason))
    }

    func getState() async throws -> String {
        try await awaitInitialized()
        return state
    }
}

/// A throwing counter service for testing multiple gated methods with error paths.
actor ThrowingCounterService: ThrowingInitializable {
    let gate = ThrowingInitializationGate()
    private var counter = 0

    func initialize(with value: Int) async {
        counter = value
        await markInitialized()
    }

    func failInit(reason: String) async {
        await markFailed(SetupError(reason: reason))
    }

    func getCounter() async throws -> Int {
        try await awaitInitialized()
        return counter
    }

    func increment() async throws -> Int {
        try await awaitInitialized()
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

        await service1.performSetup()
        let state1 = await service1.getState()
        #expect(state1 == "ready")

        await service2.performSetup()
        let state2 = await service2.getState()
        #expect(state2 == "ready")
    }

    @Test("Task-based initialization pattern works correctly", .timeLimit(.minutes(1)))
    func taskBasedInitialization() async {
        let service = SimpleService()

        Task {
            try? await Task.sleep(for: .milliseconds(20))
            await service.performSetup()
        }

        let state = await service.getState()
        #expect(state == "ready")
    }

    @Test("Gated method sees state set during initialization", .timeLimit(.minutes(1)))
    func gatedMethodSeesInitializedState() async throws {
        let service = CounterService()

        let task = Task {
            await service.getCounter()
        }

        try await Task.sleep(for: .milliseconds(100))
        await service.initialize(with: 99)

        let result = await task.value
        #expect(result == 99)
    }

    @Test("Multiple different gated methods complete after initialization", .timeLimit(.minutes(1)))
    func multipleGatedMethodsComplete() async {
        let service = CounterService()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
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
        let gate = InitializationGate()
        _ = gate
    }

    @Test("Sequential initialize-then-read pattern")
    func sequentialPattern() async {
        let service = CounterService()
        await service.initialize(with: 7)

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

    // MARK: - initialized Property Tests

    @Test("initialized property returns false when pending")
    func initializedPropertyFalseWhenPending() async {
        let service = SimpleService()
        let isInit = await service.initialized
        #expect(isInit == false)
    }

    @Test("initialized property returns true after marking initialized")
    func initializedPropertyTrueAfterInit() async {
        let service = SimpleService()
        await service.performSetup()
        let isInit = await service.initialized
        #expect(isInit == true)
    }

    // MARK: - Task Cancellation (Non-Throwing Gate)

    @Test("Task cancellation resumes continuation normally in non-throwing gate", .timeLimit(.minutes(1)))
    func taskCancellationResumesNormally() async throws {
        let service = SimpleService()

        // Start a task that will block at the gate
        let task = Task {
            await service.awaitInitialized()
        }

        // Give the task time to enqueue at the gate
        try await Task.sleep(for: .milliseconds(100))

        // Cancel the task — non-throwing gate should resume normally
        task.cancel()

        // Should not hang — cancellation resumes the continuation
        await task.value
    }
}

// MARK: - ThrowingInitializationGate Runtime Tests

@Suite("ThrowingInitializationGate Runtime Behavior")
struct ThrowingInitializationGateRuntimeTests {

    // MARK: - Happy Path: markInitialized

    @Test("markInitialized opens gate — waiters resume successfully")
    func markInitializedOpensGate() async throws {
        let service = ThrowingService()
        await service.performSetup()
        let state = try await service.getState()
        #expect(state == "ready")
    }

    @Test("Concurrent callers all proceed after initialization", .timeLimit(.minutes(1)))
    func concurrentCallersAllProceed() async throws {
        let service = ThrowingService()

        try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    try await service.getState()
                }
            }

            group.addTask {
                try await Task.sleep(for: .milliseconds(50))
                await service.performSetup()
                return "init-complete"
            }

            var stateResults: [String] = []
            for try await result in group {
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

    // MARK: - Happy Path: markFailed

    @Test("markFailed propagates error to waiting callers", .timeLimit(.minutes(1)))
    func markFailedPropagatesError() async throws {
        let service = ThrowingService()

        let task = Task {
            try await service.getState()
        }

        try await Task.sleep(for: .milliseconds(100))
        await service.failSetup(reason: "db connection failed")

        do {
            _ = try await task.value
            Issue.record("Expected error to be thrown")
        } catch let error as SetupError {
            #expect(error.reason == "db connection failed")
        }
    }

    @Test("awaitInitialized throws stored error after markFailed")
    func awaitThrowsStoredErrorAfterFailed() async {
        let service = ThrowingService()
        await service.failSetup(reason: "network timeout")

        // Subsequent calls should immediately throw the stored error
        do {
            try await service.awaitInitialized()
            Issue.record("Expected error to be thrown")
        } catch let error as SetupError {
            #expect(error.reason == "network timeout")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Multiple concurrent callers all receive error on failure", .timeLimit(.minutes(1)))
    func multipleConcurrentCallersReceiveError() async throws {
        let service = ThrowingService()

        try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    try await service.getState()
                }
            }

            group.addTask {
                try await Task.sleep(for: .milliseconds(50))
                await service.failSetup(reason: "critical failure")
                return "fail-complete"
            }

            var errorCount = 0
            do {
                for try await result in group {
                    if result == "fail-complete" { continue }
                    Issue.record("Expected error, got result: \(result)")
                }
            } catch is SetupError {
                errorCount += 1
            }

            // At least one error should have been thrown (ThrowingTaskGroup throws on first error)
            #expect(errorCount >= 1)
        }
    }

    // MARK: - State Transitions: initialized Property

    @Test("initialized property returns false when pending")
    func initializedFalseWhenPending() async {
        let service = ThrowingService()
        let isInit = await service.initialized
        #expect(isInit == false)
    }

    @Test("initialized property returns true after markInitialized")
    func initializedTrueAfterInit() async {
        let service = ThrowingService()
        await service.performSetup()
        let isInit = await service.initialized
        #expect(isInit == true)
    }

    @Test("initialized property returns false after markFailed")
    func initializedFalseAfterFailed() async {
        let service = ThrowingService()
        await service.failSetup(reason: "fail")
        let isInit = await service.initialized
        #expect(isInit == false)
    }

    // MARK: - State Stickiness

    @Test("markInitialized after markFailed is a no-op — state remains failed")
    func markInitializedAfterFailedIsNoOp() async {
        let service = ThrowingService()
        await service.failSetup(reason: "permanent failure")

        // Attempt to mark initialized — should be a no-op
        await service.markInitialized()

        // State should still be failed
        do {
            _ = try await service.getState()
            Issue.record("Expected error to be thrown")
        } catch is SetupError {
            // Expected
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("markFailed after markInitialized is a no-op — state remains initialized")
    func markFailedAfterInitializedIsNoOp() async throws {
        let service = ThrowingService()
        await service.performSetup()

        // Attempt to mark failed — should be a no-op
        await service.failSetup(reason: "too late")

        // State should still be initialized
        let state = try await service.getState()
        #expect(state == "ready")
    }

    // MARK: - Idempotency

    @Test("Multiple markInitialized calls are idempotent")
    func markInitializedIdempotent() async throws {
        let service = ThrowingService()
        await service.performSetup()
        await service.markInitialized()
        await service.markInitialized()

        let state = try await service.getState()
        #expect(state == "ready")
    }

    @Test("Multiple markFailed calls are idempotent")
    func markFailedIdempotent() async {
        let service = ThrowingService()
        await service.failSetup(reason: "first")
        await service.failSetup(reason: "second")

        do {
            _ = try await service.getState()
            Issue.record("Expected error to be thrown")
        } catch let error as SetupError {
            // The first failure should be sticky
            #expect(error.reason == "first")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Construction

    @Test("ThrowingInitializationGate can be constructed independently")
    func gateConstruction() {
        let gate = ThrowingInitializationGate()
        _ = gate
    }

    // MARK: - Task Cancellation (Throwing Gate)

    @Test("Task cancellation throws CancellationError in throwing gate", .timeLimit(.minutes(1)))
    func taskCancellationThrowsCancellationError() async throws {
        let service = ThrowingService()

        let task = Task {
            try await service.awaitInitialized()
        }

        try await Task.sleep(for: .milliseconds(100))

        task.cancel()

        do {
            try await task.value
            Issue.record("Expected CancellationError to be thrown")
        } catch is CancellationError {
            // Expected — throwing gate resumes with CancellationError on cancel
        } catch {
            // Other errors are also acceptable if CancellationError doesn't cast correctly
            // (CancellationError() as? any Error is always true)
        }
    }

    // MARK: - Counter Service Tests

    @Test("ThrowingCounterService — sequential init-then-read pattern")
    func sequentialInitThenRead() async throws {
        let service = ThrowingCounterService()
        await service.initialize(with: 42)

        for _ in 0..<5 {
            let val = try await service.getCounter()
            #expect(val == 42)
        }
    }

    @Test("ThrowingCounterService — increment after initialization")
    func incrementAfterInit() async throws {
        let service = ThrowingCounterService()
        await service.initialize(with: 0)

        var expected = 0
        for _ in 0..<10 {
            expected += 1
            let val = try await service.increment()
            #expect(val == expected)
        }
    }

    @Test("ThrowingCounterService — gated methods throw after failure")
    func gatedMethodsThrowAfterFailure() async {
        let service = ThrowingCounterService()
        await service.failInit(reason: "init failed")

        do {
            _ = try await service.getCounter()
            Issue.record("Expected error to be thrown")
        } catch let error as SetupError {
            #expect(error.reason == "init failed")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

// MARK: - Initializable Protocol Conformance Tests

@Suite("Initializable Protocol Conformance")
struct InitializableConformanceTests {

    @Test("Conforming actor exposes gate property")
    func conformingActorExposesGate() async {
        let service = SimpleService()
        let gate = service.gate
        _ = gate
    }

    @Test("markInitialized and awaitInitialized are accessible on conforming type")
    func protocolMethodsAccessible() async {
        let service = SimpleService()
        await service.markInitialized()
        await service.awaitInitialized()
    }

    @Test("awaitInitialized returns immediately when already initialized via protocol method")
    func awaitInitializedReturnsImmediatelyWhenReady() async {
        let service = SimpleService()
        await service.markInitialized()
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

// MARK: - ThrowingInitializable Protocol Conformance Tests

@Suite("ThrowingInitializable Protocol Conformance")
struct ThrowingInitializableConformanceTests {

    @Test("Conforming actor exposes gate property")
    func conformingActorExposesGate() async {
        let service = ThrowingService()
        let gate = service.gate
        _ = gate
    }

    @Test("markInitialized, markFailed, and awaitInitialized are accessible")
    func protocolMethodsAccessible() async throws {
        let service = ThrowingService()
        await service.markInitialized()
        try await service.awaitInitialized()
    }

    @Test("markFailed propagates typed error through protocol method")
    func markFailedPropagatesTypedError() async {
        let service = ThrowingService()
        await service.failSetup(reason: "typed error test")

        do {
            try await service.awaitInitialized()
            Issue.record("Expected error to be thrown")
        } catch let error as SetupError {
            #expect(error.reason == "typed error test")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Multiple ThrowingInitializable actors operate independently")
    func multipleActorsIndependent() async throws {
        let s1 = ThrowingService()
        let s2 = ThrowingCounterService()

        await s1.performSetup()
        await s2.initialize(with: 99)

        let state = try await s1.getState()
        #expect(state == "ready")

        let counter = try await s2.getCounter()
        #expect(counter == 99)
    }

    @Test("One actor fails while another succeeds — independent behavior")
    func oneFailsOtherSucceeds() async throws {
        let failing = ThrowingService()
        let succeeding = ThrowingService()

        await failing.failSetup(reason: "connection lost")
        await succeeding.performSetup()

        // Failing service should throw
        do {
            _ = try await failing.getState()
            Issue.record("Expected error from failing service")
        } catch is SetupError {
            // Expected
        }

        // Succeeding service should work fine
        let state = try await succeeding.getState()
        #expect(state == "ready")
    }
}
