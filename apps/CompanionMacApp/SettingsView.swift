import SwiftUI
import TutorConversation

struct SettingsView: View {
    @ObservedObject var model: CompanionSessionModel

    var body: some View {
        Form {
            Section("LLM-First Tutor") {
                HStack {
                    TextField("Conversation model", text: $model.tutorModelIdentifier)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                    Picker("Reasoning", selection: $model.tutorReasoningEffort) {
                        ForEach(TutorReasoningEffort.allCases, id: \.self) { effort in
                            Text(effort.rawValue).tag(effort)
                        }
                    }
                    .frame(width: 180)
                    Spacer()
                }
                Toggle(
                    "Allow Tutor conversation text, labeled context, and local measurements to be sent to OpenAI",
                    isOn: $model.tutorCloudTextConsent
                )
                Text("Without this consent, Tutor automatically uses the deterministic offline fallback. Conversation history and evidence receipts remain local; provider storage is disabled in requests.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Section("Tutor experience") {
                Picker("Explanation level", selection: $model.tutorExperienceLevel) {
                    ForEach(TutorExperienceLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Tutor explanation level")
                .accessibilityHint("Changes future Tutor responses only. Noob, Amateur, and Pro change scaffolding, not intelligence, safety, evidence, or tool authority.")
                Text("Choose how much scaffolding you want. Diagnosis, evidence standards, safety, artistic quality, and your control over Logic stay the same.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Section("Optional Tutor Audio Listening") {
                Toggle(
                    "Allow an exact bounded TrackSmith capture to be sent only when I also enable ‘Let audio model listen next turn’",
                    isOn: $model.tutorCloudAudioConsent
                )
                TextField("Audio-listening model", text: $model.tutorAudioModelIdentifier)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                Text("This consent is separate from text/measurement consent. TrackSmith rechecks the immutable WAV hash, live capture authority, metadata, and a 12 MiB byte cap immediately before upload. Local measurements alone are never labeled as model listening.")
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Section("Tutor OpenAI Credential") {
                HStack {
                    SecureField("OpenAI API credential", text: $model.tutorCredentialDraft)
                        .textFieldStyle(.roundedBorder)
                    Button("Save to Keychain") { model.saveTutorCredential() }
                        .disabled(model.tutorCredentialDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Remove", role: .destructive) { model.deleteTutorCredential() }
                }
                Text(model.tutorCredentialStatus)
                    .font(Theme.Font.meta)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Section("Future / Legacy Production Intelligence") {
                HStack {
                    Picker("Provider", selection: $model.providerSelection) {
                        ForEach(CompanionProviderSelection.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .frame(width: 300)
                    Text(model.activeProviderDescription)
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                    Spacer()
                }
            }

            if model.providerSelection.usesCloud {
                Section("Future / Legacy Cloud Consent") {
                    Toggle(
                        "Allow this request's labeled text context and measurements to be sent to the selected cloud provider",
                        isOn: $model.cloudReasoningConsent
                    )
                    Text("Captured audio is never uploaded. Provider output is untrusted, schema-validated, capability-checked, state-resolved, and converted to local deterministic DSP only after every gate passes.")
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }

                Section("Future / Legacy Credential") {
                    HStack {
                        SecureField("Provider API credential", text: $model.credentialDraft)
                            .textFieldStyle(.roundedBorder)
                        Button("Save to Keychain") { model.saveProviderCredential() }
                            .disabled(model.credentialDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Remove", role: .destructive) { model.deleteProviderCredential() }
                    }
                    Text(model.credentialStatus)
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            } else if model.providerSelection == .appleOnDevice {
                Section("Provider Availability") {
                    Text("Apple's system language model interprets bounded labeled context entirely on this Mac. It uses no API key, receives no raw audio, and has no authority over DSP or Logic state. \(model.credentialStatus)")
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            } else {
                Section("Provider Availability") {
                    Text("The deterministic offline provider remains available when credentials, consent, networking, or a cloud provider are unavailable.")
                        .font(Theme.Font.meta)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.canvas)
        .onChange(of: model.providerSelection) { _, _ in
            model.refreshCredentialStatus()
        }
        .onChange(of: model.tutorModelIdentifier) { _, _ in model.persistTutorSettings() }
        .onChange(of: model.tutorReasoningEffort) { _, _ in model.persistTutorSettings() }
        .onChange(of: model.tutorCloudTextConsent) { _, _ in model.persistTutorSettings() }
        .onChange(of: model.tutorCloudAudioConsent) { _, _ in model.persistTutorSettings() }
        .onChange(of: model.tutorAudioModelIdentifier) { _, _ in model.persistTutorSettings() }
        .onChange(of: model.tutorExperienceSettings) { _, _ in model.persistTutorSettings() }
    }
}
