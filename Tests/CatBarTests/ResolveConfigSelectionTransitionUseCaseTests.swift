import XCTest
@testable import CatBar

final class ResolveConfigSelectionTransitionUseCaseTests: XCTestCase {
    func testExecuteSkipsValidationWhenRuntimeIsStopped() {
        let useCase = ResolveConfigSelectionTransitionUseCase()

        let transition = useCase.execute(
            previousSelectedURL: URL(fileURLWithPath: "/tmp/configs/old.yaml"),
            nextSelectedURL: URL(fileURLWithPath: "/tmp/configs/new.yaml"),
            coreIsRunning: false,
            validationTiming: .afterSelection)

        XCTAssertEqual(transition.previousSelectedPath, "/tmp/configs/old.yaml")
        XCTAssertEqual(transition.nextSelectedPath, "/tmp/configs/new.yaml")
        XCTAssertNil(transition.validationRequest)
    }

    func testExecuteSkipsValidationWhenCanonicalSelectionDoesNotChange() {
        let useCase = ResolveConfigSelectionTransitionUseCase()

        let transition = useCase.execute(
            previousSelectedURL: URL(fileURLWithPath: "/tmp/configs/../configs/current.yaml"),
            nextSelectedURL: URL(fileURLWithPath: "/tmp/configs/current.yaml"),
            coreIsRunning: true,
            validationTiming: .afterSelection)

        XCTAssertNil(transition.validationRequest)
    }

    func testExecuteUsesPreviousCanonicalPathWhenValidatingBeforeSelection() {
        let useCase = ResolveConfigSelectionTransitionUseCase()

        let transition = useCase.execute(
            previousSelectedURL: URL(fileURLWithPath: "/tmp/configs/current.yaml"),
            nextSelectedURL: URL(fileURLWithPath: "/tmp/configs/next.yaml"),
            coreIsRunning: true,
            validationTiming: .beforeSelection)

        XCTAssertEqual(
            transition.validationRequest,
            ConfigSelectionValidationRequest(
                targetSelectedURL: URL(fileURLWithPath: "/tmp/configs/next.yaml"),
                staleSelectionCanonicalPath: "/tmp/configs/current.yaml"))
    }

    func testExecuteUsesNextCanonicalPathWhenValidatingAfterSelection() {
        let useCase = ResolveConfigSelectionTransitionUseCase()

        let transition = useCase.execute(
            previousSelectedURL: URL(fileURLWithPath: "/tmp/configs/current.yaml"),
            nextSelectedURL: URL(fileURLWithPath: "/tmp/configs/next.yaml"),
            coreIsRunning: true,
            validationTiming: .afterSelection)

        XCTAssertEqual(
            transition.validationRequest,
            ConfigSelectionValidationRequest(
                targetSelectedURL: URL(fileURLWithPath: "/tmp/configs/next.yaml"),
                staleSelectionCanonicalPath: "/tmp/configs/next.yaml"))
    }
}
