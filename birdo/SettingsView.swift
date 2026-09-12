//
//  SettingsView.swift
//  birdo
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("serverBaseURL") private var serverBaseURL = ""

    @State private var urlText = ""
    @State private var isTesting = false
    @State private var message: String?

    var body: some View {
        Form {
            TextField("Server URL", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .disabled(isTesting)
                .onSubmit(save)
            HStack {
                Text("BirdNET-Go server. Verified before saving; applies immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Save", action: save)
                    .disabled(isTesting || urlText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(width: 380)
        .onAppear {
            urlText = serverBaseURL
        }
    }

    private func save() {
        guard !isTesting else { return }
        message = nil
        isTesting = true
        Task {
            do {
                let base = try await ServerValidation.validate(serverURL: urlText)
                serverBaseURL = base.absoluteString
                urlText = base.absoluteString
            } catch {
                message = error.localizedDescription
            }
            isTesting = false
        }
    }
}
