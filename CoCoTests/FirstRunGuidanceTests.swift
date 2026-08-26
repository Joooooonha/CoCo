import Foundation
import Testing

@testable import CoCo

/// The tip has to survive a relaunch once it has done its job; HIG asks that a
/// first-run tip not be presented again.
@Suite(.serialized)
struct FirstRunGuidanceTests {
    @Test
    func aFreshInstallShowsTheGuidance() {
        withIsolatedDefaults { _ in
            #expect(!FirstRunGuidance.isFinished)
        }
    }

    @Test
    func finishingItPersists() {
        withIsolatedDefaults { suiteName in
            FirstRunGuidance.isFinished = true

            // A new UserDefaults over the same suite stands in for a relaunch.
            FirstRunGuidance.defaults = UserDefaults(suiteName: suiteName)!
            #expect(FirstRunGuidance.isFinished)
        }
    }

    private func withIsolatedDefaults(_ body: (String) -> Void) {
        let suiteName = "FirstRunGuidanceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        FirstRunGuidance.defaults = defaults

        body(suiteName)

        defaults.removePersistentDomain(forName: suiteName)
        FirstRunGuidance.defaults = .standard
    }
}
