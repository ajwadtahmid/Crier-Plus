import Foundation
import FoundationModels

@Generable
struct MessageSuggestions {
    @Guide(description: "A warm, friendly reminder message using the user's name")
    var friendly: String

    @Guide(description: "An energetic, motivating reminder message using the user's name")
    var motivating: String

    @Guide(description: "A clear, direct reminder message using the user's name")
    var direct: String
}
