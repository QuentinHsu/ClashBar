import Foundation
import XCTest
@testable import CatBar

final class ShouldIgnoreStreamErrorUseCaseTests: XCTestCase {
    func testExecuteIgnoresSwiftCancellationError() {
        let useCase = ShouldIgnoreStreamErrorUseCase()

        XCTAssertTrue(useCase.execute(CancellationError()))
    }

    func testExecuteIgnoresURLCancellationError() {
        let useCase = ShouldIgnoreStreamErrorUseCase()
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)

        XCTAssertTrue(useCase.execute(error))
    }

    func testExecuteKeepsRealErrorsVisible() {
        let useCase = ShouldIgnoreStreamErrorUseCase()
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)

        XCTAssertFalse(useCase.execute(error))
    }
}
