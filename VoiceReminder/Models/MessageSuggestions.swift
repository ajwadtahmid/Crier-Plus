import Foundation

// Plain struct used by views — no FoundationModels dependency.
// The @Generable counterpart lives privately inside MessageWriterService.
struct MessageSuggestions {
    let friendly: String
    let motivating: String
    let direct: String
}
