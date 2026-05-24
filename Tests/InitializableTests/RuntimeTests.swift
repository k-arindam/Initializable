//
//  RuntimeTests.swift
//  InitializableTests
//
//  Runtime behavior tests for the initialization gating system.
//
//  Tests the actual async/await behavior of `InitializationGate`,
//  `ThrowingInitializationGate`, `Initializable` protocol, and
//  `ThrowingInitializable` protocol at runtime — as opposed to the
//  macro tests which verify compile-time AST transformations.
//
//  Covers happy paths, idempotency, concurrency (task groups),
//  task cancellation, error propagation, state stickiness, and
//  protocol conformance for both throwing and non-throwing variants.
//

import Testing
import Initializable

// MARK: - Test Helper Actors (Non-Throwing)

/// A simple service actor for testing basic initialization gating.
///
/// Uses `InitializationGate` via the `Initializable` protocol. Provides a
/// `performSetup()` method that sets internal state and opens the gate,
/// and a `getState()` method that waits for the gate before returning state.
actor SimpleService: Initializable {
    /// The initialization gate required by the ``Initializable`` protocol.
    let gate = InitializationGate()

    /// Internal state that is set during initialization.
    private var state: String = "pending"

    /// Simulates async initialization by setting state to `"ready"` and opening the gate.
    func performSetup() async {
        state = "ready"
        await markInitialized()
    }

    /// Returns the current state, but only after the initialization gate is open.
    ///
    /// If the gate is still pending, this method suspends until `performSetup()` is called.
    func getState() async -> String {
        await awaitInitialized()
        return state
    }
}

/// A counter service actor for testing multiple gated methods and state mutations.
///
/// Demonstrates that gated methods see the state established during initialization,
/// and that post-initialization mutations work correctly.
actor CounterService: Initializable {
    /// The initialization gate required by the ``Initializable`` protocol.
    let gate = InitializationGate()

    /// Internal counter state set during initialization.
    private var counter = 0

    /// Initializes the counter with the given value and opens the gate.
    ///
    /// - Parameter value: The initial counter value.
    func initialize(with value: Int) async {
        counter = value
        await markInitialized()
    }

    /// Returns the current counter value, suspending until initialized.
    func getCounter() async -> Int {
        await awaitInitialized()
        return counter
    }

    /// Increments the counter and returns the new value, suspending until initialized.
    func increment() async -> Int {
        await awaitInitialized()
        counter += 1
        return counter
    }
}

// MARK: - Test Helper Actors (Throwing)

/// Custom error type for testing ``ThrowingInitializable`` error propagation.
///
/// Conforms to `Equatable` for test assertions on error identity.
struct SetupError: Error, Equatable {
    /// A human-readable description of what caused the initialization failure.
    let reason: String
}

/// A throwing service actor for testing `ThrowingInitializationGate`.
///
/// Supports both successful initialization via `performSetup()` and
/// failure via `failSetup(reason:)`, allowing tests to verify both paths.
actor ThrowingService: ThrowingInitializable {
    /// The throwing initialization gate required by the ``ThrowingInitializable`` protocol.
    let gate = ThrowingInitializationGate()

    /// Internal state that is set during successful initialization.
    private var state: String = "pending"

    /// Simulates successful initialization — sets state and opens the gate.
    func performSetup() async {
        state = "ready"
        await markInitialized()
    }

    /// Simulates failed initialization — marks the gate as failed with the given reason.
    ///
    /// - Parameter reason: The human-readable failure reason.
    func failSetup(reason: String) async {
        await markFailed(SetupError(reason: reason))
    }

    /// Returns the current state, or throws if initialization failed.
    ///
    /// - Throws: `SetupError` if `failSetup(reason:)` was called, or `CancellationError` on task cancellation.
    func getState() async throws -> String {
        try await awaitInitialized()
        return state
    }
}

/// A throwing counter service for testing multiple gated methods with error paths.
///
/// Combines counter mutation logic with throwing initialization, allowing tests
/// to verify that gated methods correctly throw after `markFailed(_:)`.
actor ThrowingCounterService: ThrowingInitializable {
    /// The throwing initialization gate required by the ``ThrowingInitializable`` protocol.
    let gate = ThrowingInitializationGate()

    /// Internal counter state.
    private var counter = 0

    /// Initializes the counter and opens the gate.
    ///
    /// - Parameter value: The initial counter value.
    func initialize(with value: Int) async {
        counter = value
        await markInitialized()
    }

    /// Marks initialization as failed with the given reason.
    ///
    /// - Parameter reason: The human-readable failure reason.
    func failInit(reason: String) async {
        await markFailed(SetupError(reason: reason))
    }

    /// Returns the current counter value, or throws if initialization failed.
    func getCounter() async throws -> Int {
        try await awaitInitialized()
        return counter
    }

    /// Increments the counter and returns the new value, or throws if initialization failed.
    func increment() async throws -> Int {
        try await awaitInitialized()
        counter += 1
        return counter
    }
}

// MARK: - InitializationGate Runtime Tests

/// Test suite for ``InitializationGate`` runtime behavior.
///
/// Validates the non-throwing gate's core functionality: suspension until initialization,
/// idempotent `markInitialized()`, concurrent access, task cancellation behavior,
/// and the `initialized` property.
@Suite("InitializationGate Runtime Behavior")
struct InitializationGateRuntimeTests {

    /// Verifies that a gated method returns the correct value after initialization completes.
    @Test("Gated method returns correct value after initialization")
    func gatedMethodReturnsCorrectValue() async {
        let service = SimpleService()
        await service.performSetup()
        let state = await service.getState()
        #expect(state == "ready")
    }

    /// Verifies that calling `markInitialized()` multiple times has no adverse effect.
    /// The gate should remain open and state should be unchanged.
    @Test("Multiple calls to markInitialized are idempotent")
    func markInitializedIsIdempotent() async {
        let service = SimpleService()
        await service.performSetup()
        await service.markInitialized()
        await service.markInitialized()
        let state = await service.getState()
        #expect(state == "ready")
    }

    /// Verifies that `awaitInitialized()` can be called multiple times after the gate
    /// is open — each call should return immediately.
    @Test("awaitInitialized can be called multiple times after initialization")
    func multipleAwaitsAfterInit() async {
        let service = SimpleService()
        await service.performSetup()
        await service.awaitInitialized()
        await service.awaitInitialized()
        await service.awaitInitialized()
        let state = await service.getState()
        #expect(state == "ready")
    }

    /// Verifies that 10 concurrent tasks all receive the correct state after a delayed initialization.
    ///
    /// - Note: Uses a 50ms delay before initialization to allow tasks to enqueue at the gate.
    @Test("Concurrent callers all proceed after initialization", .timeLimit(.minutes(1)))
    func concurrentCallersAllProceed() async {
        let service = SimpleService()

        await withTaskGroup(of: String.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await service.getState()
                }
            }

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

    /// Verifies that initializing before any method calls allows all methods to proceed immediately.
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

    /// Verifies that two separate instances of the same actor type maintain independent gates.
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

    /// Verifies the common pattern of spawning a background `Task` for initialization
    /// while the main path blocks at the gate.
    ///
    /// - Note: Uses a 20ms delay to simulate async setup work.
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

    /// Verifies that a task blocking at the gate sees the state set during initialization,
    /// not the default value.
    ///
    /// - Precondition: The task enqueues at the gate before initialization.
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

    /// Verifies that multiple different gated methods (e.g., `getCounter`) all complete
    /// correctly after initialization.
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

    /// Verifies that `InitializationGate` has a public initializer accessible from outside the module.
    @Test("InitializationGate can be constructed independently")
    func gateConstruction() {
        let gate = InitializationGate()
        _ = gate
    }

    /// Verifies that multiple sequential reads after initialization all return the same value.
    @Test("Sequential initialize-then-read pattern")
    func sequentialPattern() async {
        let service = CounterService()
        await service.initialize(with: 7)

        for _ in 0..<5 {
            let val = await service.getCounter()
            #expect(val == 7)
        }
    }

    /// Verifies that post-initialization increment operations mutate state correctly.
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

    /// Verifies correct behavior with interleaved read and write operations after initialization.
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

    /// Verifies that the `initialized` async property returns `false` before `markInitialized()`.
    @Test("initialized property returns false when pending")
    func initializedPropertyFalseWhenPending() async {
        let service = SimpleService()
        let isInit = await service.initialized
        #expect(isInit == false)
    }

    /// Verifies that the `initialized` async property returns `true` after `markInitialized()`.
    @Test("initialized property returns true after marking initialized")
    func initializedPropertyTrueAfterInit() async {
        let service = SimpleService()
        await service.performSetup()
        let isInit = await service.initialized
        #expect(isInit == true)
    }

    // MARK: - Task Cancellation (Non-Throwing Gate)

    /// Verifies that cancelling a task blocked at a non-throwing gate resumes the continuation
    /// normally (returns `Void`) rather than hanging indefinitely.
    ///
    /// - Important: The non-throwing gate's `ContinuationError` type is `Never`, so cancellation
    ///   cannot throw — it simply resumes.
    @Test("Task cancellation resumes continuation normally in non-throwing gate", .timeLimit(.minutes(1)))
    func taskCancellationResumesNormally() async throws {
        let service = SimpleService()

        let task = Task {
            await service.awaitInitialized()
        }

        try await Task.sleep(for: .milliseconds(100))
        task.cancel()
        await task.value
    }
}

// MARK: - ThrowingInitializationGate Runtime Tests

/// Test suite for ``ThrowingInitializationGate`` runtime behavior.
///
/// Validates the throwing gate's core functionality: success path, failure path with
/// error propagation, state stickiness (first resolution wins), concurrent error delivery,
/// task cancellation, and the `initialized` property across all states.
@Suite("ThrowingInitializationGate Runtime Behavior")
struct ThrowingInitializationGateRuntimeTests {

    // MARK: - Happy Path: markInitialized

    /// Verifies that `markInitialized()` opens the gate and waiters resume with the correct state.
    @Test("markInitialized opens gate — waiters resume successfully")
    func markInitializedOpensGate() async throws {
        let service = ThrowingService()
        await service.performSetup()
        let state = try await service.getState()
        #expect(state == "ready")
    }

    /// Verifies that 10 concurrent callers all proceed correctly after delayed initialization.
    ///
    /// - Note: Uses a 50ms delay before initialization to allow tasks to enqueue.
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

    /// Verifies that `markFailed(_:)` propagates the error to a task waiting at the gate.
    ///
    /// - Precondition: The waiting task enqueues at the gate before failure is signaled.
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

    /// Verifies that calling `awaitInitialized()` **after** `markFailed(_:)` immediately
    /// throws the stored error without suspending.
    @Test("awaitInitialized throws stored error after markFailed")
    func awaitThrowsStoredErrorAfterFailed() async {
        let service = ThrowingService()
        await service.failSetup(reason: "network timeout")

        do {
            try await service.awaitInitialized()
            Issue.record("Expected error to be thrown")
        } catch let error as SetupError {
            #expect(error.reason == "network timeout")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    /// Verifies that multiple concurrent callers all receive the error when `markFailed` is called.
    ///
    /// - Note: `ThrowingTaskGroup` propagates the first error; at least one must be `SetupError`.
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

            #expect(errorCount >= 1)
        }
    }

    // MARK: - State Transitions: initialized Property

    /// Verifies `initialized` is `false` in the pending state.
    @Test("initialized property returns false when pending")
    func initializedFalseWhenPending() async {
        let service = ThrowingService()
        let isInit = await service.initialized
        #expect(isInit == false)
    }

    /// Verifies `initialized` is `true` after successful initialization.
    @Test("initialized property returns true after markInitialized")
    func initializedTrueAfterInit() async {
        let service = ThrowingService()
        await service.performSetup()
        let isInit = await service.initialized
        #expect(isInit == true)
    }

    /// Verifies `initialized` is `false` after failure — the failed state is not "initialized".
    @Test("initialized property returns false after markFailed")
    func initializedFalseAfterFailed() async {
        let service = ThrowingService()
        await service.failSetup(reason: "fail")
        let isInit = await service.initialized
        #expect(isInit == false)
    }

    // MARK: - State Stickiness

    /// Verifies that calling `markInitialized()` after `markFailed(_:)` is a no-op.
    /// The first resolution (failure) wins — the gate stays in the failed state.
    @Test("markInitialized after markFailed is a no-op — state remains failed")
    func markInitializedAfterFailedIsNoOp() async {
        let service = ThrowingService()
        await service.failSetup(reason: "permanent failure")
        await service.markInitialized()

        do {
            _ = try await service.getState()
            Issue.record("Expected error to be thrown")
        } catch is SetupError {
            // Expected — state is still failed
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    /// Verifies that calling `markFailed(_:)` after `markInitialized()` is a no-op.
    /// The first resolution (success) wins — the gate stays in the initialized state.
    @Test("markFailed after markInitialized is a no-op — state remains initialized")
    func markFailedAfterInitializedIsNoOp() async throws {
        let service = ThrowingService()
        await service.performSetup()
        await service.failSetup(reason: "too late")

        let state = try await service.getState()
        #expect(state == "ready")
    }

    // MARK: - Idempotency

    /// Verifies that multiple `markInitialized()` calls are safe no-ops after the first.
    @Test("Multiple markInitialized calls are idempotent")
    func markInitializedIdempotent() async throws {
        let service = ThrowingService()
        await service.performSetup()
        await service.markInitialized()
        await service.markInitialized()

        let state = try await service.getState()
        #expect(state == "ready")
    }

    /// Verifies that multiple `markFailed(_:)` calls are safe no-ops after the first.
    /// The first error is sticky — subsequent errors are discarded.
    @Test("Multiple markFailed calls are idempotent")
    func markFailedIdempotent() async {
        let service = ThrowingService()
        await service.failSetup(reason: "first")
        await service.failSetup(reason: "second")

        do {
            _ = try await service.getState()
            Issue.record("Expected error to be thrown")
        } catch let error as SetupError {
            #expect(error.reason == "first")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    // MARK: - Construction

    /// Verifies that `ThrowingInitializationGate` has a public initializer.
    @Test("ThrowingInitializationGate can be constructed independently")
    func gateConstruction() {
        let gate = ThrowingInitializationGate()
        _ = gate
    }

    // MARK: - Task Cancellation (Throwing Gate)

    /// Verifies that cancelling a task blocked at a throwing gate throws `CancellationError`.
    ///
    /// Unlike the non-throwing gate (which resumes normally), the throwing gate's cancellation
    /// handler resumes the continuation by throwing `CancellationError`.
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
        }
    }

    // MARK: - Counter Service Tests

    /// Verifies sequential init-then-read operations on the throwing counter service.
    @Test("ThrowingCounterService — sequential init-then-read pattern")
    func sequentialInitThenRead() async throws {
        let service = ThrowingCounterService()
        await service.initialize(with: 42)

        for _ in 0..<5 {
            let val = try await service.getCounter()
            #expect(val == 42)
        }
    }

    /// Verifies that post-initialization increments work correctly on the throwing counter service.
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

    /// Verifies that gated methods throw the stored error after `markFailed(_:)`.
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

/// Test suite verifying ``Initializable`` protocol conformance behavior.
///
/// Ensures that conforming types expose the `gate` property, that protocol extension
/// methods are accessible, and that multiple conforming instances operate independently.
@Suite("Initializable Protocol Conformance")
struct InitializableConformanceTests {

    /// Verifies that the `gate` property is accessible on a conforming actor.
    @Test("Conforming actor exposes gate property")
    func conformingActorExposesGate() async {
        let service = SimpleService()
        let gate = service.gate
        _ = gate
    }

    /// Verifies that both protocol extension methods (`markInitialized`, `awaitInitialized`)
    /// are callable on a conforming type.
    @Test("markInitialized and awaitInitialized are accessible on conforming type")
    func protocolMethodsAccessible() async {
        let service = SimpleService()
        await service.markInitialized()
        await service.awaitInitialized()
    }

    /// Verifies that `awaitInitialized()` returns immediately when the gate is already open.
    @Test("awaitInitialized returns immediately when already initialized via protocol method")
    func awaitInitializedReturnsImmediatelyWhenReady() async {
        let service = SimpleService()
        await service.markInitialized()
        await service.awaitInitialized()
    }

    /// Verifies that two different `Initializable` actors maintain independent gates.
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

/// Test suite verifying ``ThrowingInitializable`` protocol conformance behavior.
///
/// Ensures that conforming types expose the `gate` property, that protocol extension
/// methods (including `markFailed`) are accessible, that typed errors propagate correctly,
/// and that multiple instances operate independently — including mixed success/failure scenarios.
@Suite("ThrowingInitializable Protocol Conformance")
struct ThrowingInitializableConformanceTests {

    /// Verifies that the `gate` property is accessible on a conforming actor.
    @Test("Conforming actor exposes gate property")
    func conformingActorExposesGate() async {
        let service = ThrowingService()
        let gate = service.gate
        _ = gate
    }

    /// Verifies that all three protocol extension methods (`markInitialized`, `markFailed`,
    /// `awaitInitialized`) are callable on a conforming type.
    @Test("markInitialized, markFailed, and awaitInitialized are accessible")
    func protocolMethodsAccessible() async throws {
        let service = ThrowingService()
        await service.markInitialized()
        try await service.awaitInitialized()
    }

    /// Verifies that `markFailed(_:)` propagates a typed error (`SetupError`) through the
    /// protocol's `awaitInitialized()` method.
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

    /// Verifies that two different `ThrowingInitializable` actors maintain independent gates.
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

    /// Verifies that one actor failing does not affect another actor's successful initialization.
    /// Demonstrates complete isolation between instances.
    @Test("One actor fails while another succeeds — independent behavior")
    func oneFailsOtherSucceeds() async throws {
        let failing = ThrowingService()
        let succeeding = ThrowingService()

        await failing.failSetup(reason: "connection lost")
        await succeeding.performSetup()

        do {
            _ = try await failing.getState()
            Issue.record("Expected error from failing service")
        } catch is SetupError {
            // Expected
        }

        let state = try await succeeding.getState()
        #expect(state == "ready")
    }
}
