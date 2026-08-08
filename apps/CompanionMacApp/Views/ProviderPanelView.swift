import SwiftUI

struct ProviderPanelView: View {
    @ObservedObject var model: CompanionSessionModel

    var body: some View {
        GroupBox("Production Intelligence") {
            VStack(alignment: .leading, spacing: Theme.Spacing.legacy10) {
                HStack {
                    Picker("Provider", selection: $model.providerSelection) {
                        ForEach(CompanionProviderSelection.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .frame(width: 300)
                    Text(model.activeProviderDescription)
                        .font(Theme.Font.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                if model.providerSelection.usesCloud {
                    Toggle(
                        "Allow this request's labeled text context and measurements to be sent to the selected cloud provider",
                        isOn: $model.cloudReasoningConsent
                    )
                    Text("Captured audio is never uploaded. Provider output is untrusted, schema-validated, capability-checked, state-resolved, and converted to local deterministic DSP only after every gate passes.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        SecureField("Provider API credential", text: $model.credentialDraft)
                            .textFieldStyle(.roundedBorder)
                        Button("Save to Keychain") { model.saveProviderCredential() }
                            .disabled(model.credentialDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Remove", role: .destructive) { model.deleteProviderCredential() }
                    }
                    Text(model.credentialStatus)
                        .font(Theme.Font.caption)
                        .foregroundStyle(.secondary)
                } else if model.providerSelection == .appleOnDevice {
                    Text("Apple's system language model interprets bounded labeled context entirely on this Mac. It uses no API key, receives no raw audio, and has no authority over DSP or Logic state. \(model.credentialStatus)")
                        .font(Theme.Font.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("The deterministic offline provider remains available when credentials, consent, networking, or a cloud provider are unavailable.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(.secondary)
                }
                if !model.restoredConversationStatus.isEmpty {
                    Text(model.restoredConversationStatus)
                        .font(Theme.Font.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Theme.Spacing.eight)
        }
    }
}
