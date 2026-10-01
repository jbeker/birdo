//
//  BirdCardView.swift
//  birdo
//
//  Card layout shared by the live list and the Today list, plus the card for
//  a bird currently being heard. Shared by macOS and iOS.
//

import SwiftUI

/// Photo, linked common name, scientific name, a caption line, and a
/// trailing accessory. The two lists differ only in the last two.
struct BirdCard<Detail: View, Trailing: View>: View {
    let commonName: String
    let scientificName: String
    let imageURL: URL?
    let linkURL: URL?
    let linkSiteName: String
    let photoCredit: String
    var dimmed = false
    let detail: Detail
    let trailing: Trailing

    @Environment(\.openURL) private var openURL
    @State private var hoveringName = false

    init(commonName: String, scientificName: String, imageURL: URL?, linkURL: URL?,
         linkSiteName: String, photoCredit: String, dimmed: Bool = false,
         @ViewBuilder detail: () -> Detail, @ViewBuilder trailing: () -> Trailing) {
        self.commonName = commonName
        self.scientificName = scientificName
        self.imageURL = imageURL
        self.linkURL = linkURL
        self.linkSiteName = linkSiteName
        self.photoCredit = photoCredit
        self.dimmed = dimmed
        self.detail = detail()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                nameLink
                Text(scientificName)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                detail
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            trailing
        }
        .padding(10)
        .background(.thinMaterial, in: .rect(cornerRadius: 12))
        .opacity(dimmed ? 0.55 : 1)
    }

    private var nameLink: some View {
        Button {
            if let linkURL {
                openURL(linkURL)
            }
        } label: {
            HStack(spacing: 3) {
                Text(commonName)
                    .font(.headline)
                    .lineLimit(1)
                Image(systemName: "arrow.up.forward")
                    .font(.caption2.weight(.semibold))
                    .opacity(linkArrowOpacity)
            }
            .foregroundStyle(hoveringName ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .pointerStyle(.link)
        .onHover { hoveringName = $0 }
        .animation(.easeOut(duration: 0.12), value: hoveringName)
        #endif
        .help(String(localized: "View on \(linkSiteName)"))
    }

    private var linkArrowOpacity: Double {
        #if os(macOS)
        hoveringName ? 1 : 0
        #else
        0.4  // no hover on touch; keep a faint hint that the name is a link
        #endif
    }

    private var thumbnail: some View {
        AsyncImage(url: imageURL) { image in
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
}

/// One card for a bird currently being heard.
struct BirdCardView: View {
    let bird: PendingBird

    @Environment(NowHearingModel.self) private var model

    var body: some View {
        BirdCard(
            commonName: bird.species,
            scientificName: bird.scientificName,
            imageURL: model.imageURL(for: bird),
            linkURL: model.databaseURL(for: bird),
            linkSiteName: model.databaseName(for: bird),
            photoCredit: photoCredit,
            dimmed: bird.isLingering && !isPlaying
        ) {
            HStack(spacing: 4) {
                Label(bird.source, systemImage: "mic.fill")
                if let percent = bird.confidencePercent {
                    Text("· \(percent)%")
                }
            }
        } trailing: {
            playButton
        }
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
