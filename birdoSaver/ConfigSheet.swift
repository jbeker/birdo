//
//  ConfigSheet.swift
//  birdoSaver
//
//  The Options… sheet shown by System Settings: a single field for the
//  BirdNET-Go server address, validated before saving.
//

import AppKit
import SwiftUI

final class ConfigSheetController {
    let window: NSWindow

    init() {
        // `dismiss` is captured by reference and filled in once the window
        // exists — the view needs the closure before the window is made.
        var dismiss: () -> Void = {}
        let host = NSHostingController(rootView: ConfigSheetView { dismiss() })
        // NSWindow(contentViewController:) sizes the window to the SwiftUI
        // content; setting contentView on a zero-height window does not.
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled]
        window.isReleasedWhenClosed = false
        self.window = window
        dismiss = { [weak window] in
            guard let window else { return }
            if let parent = window.sheetParent {
                parent.endSheet(window)
            } else {
                window.close()
            }
        }
    }
}

private struct ConfigSheetView: View {
    var dismiss: () -> Void

    @State private var urlText = SaverDefaults.serverBaseURL?.absoluteString ?? ""
    @State private var isValidating = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Birdo Screen Saver")
                .font(.headline)
            Text("Shows the birds your BirdNET-Go server is hearing right now.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("Server address", text: $urlText, prompt: Text("birdnet.example.com"))
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
                .onSubmit { save() }
            if let errorText {
                Text(errorText)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button {
                    save()
                } label: {
                    if isValidating {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 34)
                    } else {
                        Text("Save")
                            .frame(width: 34)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func save() {
        guard !isValidating else { return }
        isValidating = true
        errorText = nil
        Task {
            defer { isValidating = false }
            do {
                let base = try await ServerValidation.validate(serverURL: urlText)
                SaverDefaults.setServerBaseURL(base)
                dismiss()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}
