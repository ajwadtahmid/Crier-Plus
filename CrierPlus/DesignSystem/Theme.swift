import SwiftUI

enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum CornerRadius {
        static let card: CGFloat = 16
        static let button: CGFloat = 12
    }

    enum Typography {
        static let time = Font.system(.largeTitle, design: .rounded).weight(.semibold)
        static let title = Font.title
        static let body = Font.body
        static let caption = Font.caption
    }

    enum Layout {
        static let minimumTapTarget: CGFloat = 44
    }
}

extension Color {
    static let appPrimary = Color("Primary")
    static let appPrimaryDeep = Color("PrimaryDeep")
    static let appSecondary = Color("Secondary")
    static let appAccent = Color("Accent")
    static let appDestructive = Color("Destructive")
    static let appBackground = Color("Background")
    static let appSecondaryBackground = Color("SecondaryBackground")
    static let appBorder = Color("Border")
    static let appTextPrimary = Color("TextPrimary")
    static let appTextSecondary = Color("TextSecondary")
}
