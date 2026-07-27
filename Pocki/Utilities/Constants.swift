import Foundation

/// App-wide constants for Pocki.
enum Constants {
    static let appName = "Pocki"
    static let tagline = "Your money, simplified."
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    enum Layout {
        static let cardRadius: CGFloat = 20
        static let buttonRadius: CGFloat = 16
        static let iconSize: CGFloat = 40
        static let floatingButtonSize: CGFloat = 60
        static let horizontalPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 24
    }

    enum Budget {
        static let defaultMonthly: Double = 2000
        static let warningThreshold: Double = 0.8
    }
}
