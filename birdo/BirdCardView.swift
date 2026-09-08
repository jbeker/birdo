//
//  BirdCardView.swift
//  birdo
//
//  One card for a bird currently being heard.
//

import SwiftUI

struct BirdCardView: View {
    let bird: PendingBird

    @Environment(NowHearingModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(bird.species)
                    .font(.headline)
                    .lineLimit(1)
                Text(bird.scientificName)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Label(bird.source, systemImage: "mic.fill")
                    if let percent = bird.confidencePercent {
                        Text("· \(percent)%")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            playButton
        }
        .padding(10)
        .background(.thinMaterial, in: .rect(cornerRadius: 12))
        .opacity(bird.isLingering && !isPlaying ? 0.55 : 1)
    }

    private var thumbnail: some View {
        AsyncImage(url: model.imageURL(for: bird)) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                Rectangle()
                    .fill(.quaternary)
                Image(systemName: "bird")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(.rect(cornerRadius: 10))
        .help(photoCredit)
    }

    private var photoCredit: String {
        if let author = model.photoCredit[bird.scientificName] {
            String(localized: "Photo: \(author)")
        } else {
            bird.species
        }
    }

    private var playButton: some View {
        Button {
            model.togglePlayback(for: bird)
        } label: {
            ZStack {
                if isPlaying {
                    Circle()
                        .stroke(.quaternary, lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: model.audioPlayer.progress)
                        .stroke(.tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Label(isPlaying ? "Stop" : "Play latest clip",
                      systemImage: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .labelStyle(.iconOnly)
                    .font(.title2)
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.borderless)
        .disabled(!model.clipAvailable(for: bird))
        .help(model.clipAvailable(for: bird)
              ? (isPlaying ? String(localized: "Stop") : String(localized: "Play latest clip"))
              : String(localized: "No recorded clip yet"))
    }

    private var isPlaying: Bool {
        model.audioPlayer.currentKey == bird.id
    }
}
