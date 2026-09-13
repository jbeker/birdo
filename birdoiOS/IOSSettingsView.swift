//
//  IOSSettingsView.swift
//  birdo
//
//  Server address and widget preferences, presented as a sheet.
//

import SwiftUI
import WidgetKit

struct IOSSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppGroup.serverURLKey, store: AppGroup.defaults) private var serverBaseURL = ""
    @AppStorage(AppGroup.widgetWindowKey, store: AppGroup.defaults) private var widgetWindow = AppGroup.defaultWidgetWindow

    @State private var urlText = ""
    @State private var isTesting = false
    @State private var message: String?

    private static let windowChoices = [10, 15, 30, 60]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Server URL", text: $urlText, prompt: Text(verbatim: "https://birdnet.example.com"))
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isTesting)
                        .onSubmit(save)
                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Button(action: save) {
                        if isTesting {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isTesting || urlText.trimmingCharacters(in: .whitespaces).isEmpty
                              || urlText == serverBaseURL)
                } header: {
                    Text("BirdNET-Go server")
                } footer: {
                    Text("Verified before saving; applies immediately.")
                }

                Section {
                    Picker("Window", selection: $widgetWindow) {
                        ForEach(Self.windowChoices, id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                } header: {
                    Text("Most Heard widget")
                } footer: {
                    Text("How far back the widget looks when ranking birds, and roughly how often it refreshes. Each widget can override this in its own settings.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { urlText = serverBaseURL }
            .onChange(of: widgetWindow) {
                WidgetCenter.shared.reloadAllTimelines()
            }
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
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                message = error.localizedDescription
            }
            isTesting = false
        }
    }
}

#Preview {
    IOSSettingsView()
}
