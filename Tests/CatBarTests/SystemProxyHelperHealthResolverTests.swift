import ServiceManagement
import XCTest
@testable import CatBar

final class SystemProxyHelperHealthResolverTests: XCTestCase {
    private let resolver = SystemProxyHelperHealthResolver()

    func testRegistrationStateMapsKnownStatuses() {
        XCTAssertEqual(self.resolver.registrationState(from: .enabled), .enabled)
        XCTAssertEqual(self.resolver.registrationState(from: .requiresApproval), .requiresApproval)
        XCTAssertEqual(self.resolver.registrationState(from: .notRegistered), .notRegistered)
        XCTAssertEqual(self.resolver.registrationState(from: .notFound), .unavailable)
    }

    func testFailureReasonMapsServiceErrors() {
        XCTAssertEqual(
            self.resolver.failureReason(for: SystemProxyServiceError.helperNeedsApproval),
            .backgroundActivityDisabled)
        XCTAssertEqual(
            self.resolver.failureReason(for: SystemProxyServiceError.helperInvalidSignature("mismatch")),
            .signatureMismatch)
    }

    func testFailedHealthSnapshotUsesMappedReasonAndMessage() {
        let snapshot = self.resolver.failedHealthSnapshot(
            registrationState: .requiresApproval,
            backgroundActivityAllowed: false,
            processRunning: false,
            error: SystemProxyServiceError.helperNeedsApproval)

        XCTAssertEqual(snapshot.failureReason, .backgroundActivityDisabled)
        XCTAssertEqual(snapshot.rawMessage, SystemProxyServiceError.helperNeedsApproval.localizedDescription)
    }

    func testLikelyApprovalErrorMatchesKnownPhrases() {
        let error = NSError(domain: "test", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Operation not permitted by background item policy."
        ])

        XCTAssertTrue(self.resolver.isLikelyApprovalError(error))
    }
}
