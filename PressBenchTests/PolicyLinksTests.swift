import XCTest
@testable import PressBench

final class PolicyLinksTests: XCTestCase {
    func testPolicyLinksUseCanonicalSecureGitHubPagesRoutes() {
        let expected: [URL: String] = [
            PressBenchPolicyLinks.privacy: "https://lrodeveloperr.github.io/pressbench-legal/privacy/",
            PressBenchPolicyLinks.terms: "https://lrodeveloperr.github.io/pressbench-legal/terms/",
            PressBenchPolicyLinks.safety: "https://lrodeveloperr.github.io/pressbench-legal/safety/",
            PressBenchPolicyLinks.purchases: "https://lrodeveloperr.github.io/pressbench-legal/subscriptions/",
            PressBenchPolicyLinks.support: "https://lrodeveloperr.github.io/pressbench-legal/support/",
            PressBenchPolicyLinks.dataChoices: "https://lrodeveloperr.github.io/pressbench-legal/data-choices/",
            PressBenchPolicyLinks.accessibility: "https://lrodeveloperr.github.io/pressbench-legal/accessibility/",
            PressBenchPolicyLinks.thirdPartyNotices: "https://lrodeveloperr.github.io/pressbench-legal/third-party-notices/"
        ]

        XCTAssertEqual(PressBenchPolicyLinks.all.count, expected.count)
        XCTAssertEqual(Set(PressBenchPolicyLinks.all), Set(expected.keys))

        for url in PressBenchPolicyLinks.all {
            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.host, "lrodeveloperr.github.io")
            XCTAssertEqual(url.absoluteString, expected[url])
        }
    }
}
