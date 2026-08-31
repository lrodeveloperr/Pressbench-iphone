import Foundation

enum PressBenchPolicyLinks {
    static let site = URL(string: "https://lrodeveloperr.github.io/pressbench-legal/")!
    static let privacy = URL(string: "https://lrodeveloperr.github.io/pressbench-legal/privacy/")!
    static let terms = URL(string: "https://lrodeveloperr.github.io/pressbench-legal/terms/")!
    static let safety = URL(string: "https://lrodeveloperr.github.io/pressbench-legal/safety/")!
    static let purchases = URL(string: "https://lrodeveloperr.github.io/pressbench-legal/subscriptions/")!
    static let manageSubscription = URL(string: "https://apps.apple.com/account/subscriptions")!
    static let support = URL(string: "https://lrodeveloperr.github.io/pressbench-legal/support/")!
    static let dataChoices = URL(string: "https://lrodeveloperr.github.io/pressbench-legal/data-choices/")!
    static let accessibility = URL(string: "https://lrodeveloperr.github.io/pressbench-legal/accessibility/")!
    static let thirdPartyNotices = URL(string: "https://lrodeveloperr.github.io/pressbench-legal/third-party-notices/")!

    static let all: [URL] = [
        privacy, terms, safety, purchases, support, dataChoices, accessibility, thirdPartyNotices
    ]
}
