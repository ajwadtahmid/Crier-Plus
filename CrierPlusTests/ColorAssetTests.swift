import Testing
import UIKit

struct ColorAssetTests {
    static let assetColorNames = [
        "Primary", "PrimaryDeep", "Secondary", "Accent", "Destructive",
        "Background", "SecondaryBackground", "Border", "TextPrimary", "TextSecondary",
    ]

    @Test(arguments: assetColorNames)
    func colorResolves(named name: String) {
        #expect(UIColor(named: name, in: .main, compatibleWith: nil) != nil)
    }

    @Test(arguments: assetColorNames)
    func colorResolvesInDarkMode(named name: String) {
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        #expect(UIColor(named: name, in: .main, compatibleWith: darkTraits) != nil)
    }
}
