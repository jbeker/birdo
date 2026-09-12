//
//  SaverRootView.swift
//  birdoSaver
//
//  The whole scene: ambient gradient behind cards that fade in and out
//  as birds start and stop singing.
//

import SwiftUI

struct SaverRootView: View {
    let model: SaverModel

    var body: some View {
        ZStack {
            AmbientBackgroundView()
            if model.baseURL == nil {
                Text("Open Options to set your BirdNET-Go server address.")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(.white.opacity(0.55))
            }
            ForEach(model.cards) { card in
                BirdSaverCardView(card: card, baseURL: model.baseURL)
                    // Departure fades the card in place (timing set by the
                    // model's withAnimation); the view leaves the tree only
                    // once fully transparent, so removal needs no transition.
                    .opacity(card.departingAt == nil ? 1 : 0)
                    .position(x: card.frame.midX, y: card.frame.midY)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.97)),
                        removal: .identity
                    ))
            }
        }
        // Materials and text are tuned for the dark gradient; don't let a
        // light system appearance wash them out.
        .environment(\.colorScheme, .dark)
        .ignoresSafeArea()
    }
}
