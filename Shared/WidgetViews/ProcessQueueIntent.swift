import AppIntents
import FusionhaKit

struct ProcessQueueIntent: AppIntent {
    static let title: LocalizedStringResource = "Process queue now"
    static let description = IntentDescription("Asks fusionha to check its download clients and import anything finished.")

    func perform() async throws -> some IntentResult {
        try await CredentialStore.client()?.processQueue()
        return .result()
    }
}
