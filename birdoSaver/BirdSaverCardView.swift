//
//  BirdSaverCardView.swift
//  birdoSaver
//
//  One bird on screen: photo on the left, common and scientific names
//  stacked on the right. Deliberately no microphone or confidence —
//  this is decor, not a dashboard.
//

import SwiftUI

struct BirdSaverCardView: View {
    let card: SaverModel.Card
    let baseURL: URL?

    var body: some View {
        // Everything scales off the card footprint so the System Settings
        // preview gets proportionally tiny cards.
        let scale = card.frame.width / 440

        HStack(spacing: 18 * scale) {
            AsyncImage(url: URL(string: card.thumbnail, relativeTo: baseURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    Rectangle().fill(.white.opacity(0.06))
                    Image(systemName: "bird")
                        .font(.system(size: 40 * scale))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .frame(width: 150 * scale, height: 150 * scale)
            .clipShape(.rect(cornerRadius: 14 * scale))

            VStack(alignment: .leading, spacing: 6 * scale) {
                Text(card.species)
                    .font(.system(size: 28 * scale, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(card.scientificName)
                    .font(.system(size: 17 * scale, design: .serif))
                    .italic()
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(2)
            }
            .minimumScaleFactor(0.6)
            .shadow(color: .black.opacity(0.4), radius: 2 * scale, y: 1 * scale)

            Spacer(minLength: 0)
        }
        .padding(20 * scale)
        .frame(width: card.frame.width, height: card.frame.height)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 22 * scale))
        .overlay {
            RoundedRectangle(cornerRadius: 22 * scale)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 18 * scale, y: 8 * scale)
    }
}
