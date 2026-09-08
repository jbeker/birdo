//
//  OnboardingView.swift
//  birdo
//
//  First-launch setup: explains the app and collects a working server URL.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("serverBaseURL") private var serverBaseURL = ""

    @State private var urlText = ""
    @State private var isTesting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bird.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Welcome to birdo")
                .font(.title2.bold())
            Text("birdo shows which birds your BirdNET-Go station is hearing right now — live species cards with photos, the microphone that heard them, and playback of the recorded clips.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            TextField("Server URL", text: $urlText, prompt: Text(verbatim: "https://birdnet.example.com"))
                .textFieldStyle(.roundedBorder)
                .disabled(isTesting)
                .onSubmit(connect)
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Button(action: connect) {
                if isTesting {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: 60)
                } else {
                    Text("Connect")
                        .frame(minWidth: 60)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isTesting || urlText.trimmingCharacters(in: .whitespaces).isEmpty)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func connect() {
        guard !isTesting else { return }
        errorMessage = nil
        isTesting = true
        Task {
            do {
                let base = try await NowHearingModel.validate(serverURL: urlText)
                serverBaseURL = base.absoluteString  // flips the app to the main view
            } catch {
                errorMessage = error.localizedDescription
            }
            isTesting = false
        }
    }
}

#Preview {
    OnboardingView()
        .frame(width: 340, height: 440)
}
