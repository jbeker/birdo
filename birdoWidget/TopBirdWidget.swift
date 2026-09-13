//
//  TopBirdWidget.swift
//  birdoWidget
//
//  "Most Heard": the bird detected most often in a trailing window.
//

import SwiftUI
import WidgetKit

struct TopBirdWidget: Widget {
    let kind = "TopBirdWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TopBirdConfigurationIntent.self, provider: TopBirdProvider()) { entry in
            TopBirdWidgetView(entry: entry)
        }
        .configurationDisplayName("Most Heard")
        .description("The bird your BirdNET-Go station has heard most often in the last few minutes.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

struct TopBirdWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetContentMargins) private var margins
    let entry: TopBirdEntry

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .systemMedium: medium
        case .systemLarge, .systemExtraLarge: large
        default: small
        }
    }

    // MARK: - Home Screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            Spacer(minLength: 0)
            if let headline = entry.headline {
                Text(headline.commonName)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(headline.scientificName)
                    .font(.caption2)
                    .italic()
                    .lineLimit(2)
                    .opacity(0.85)
            } else {
                Label(messageTitle, systemImage: messageSymbol)
                    .font(.headline)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .lineLimit(2)
            }
            staleLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(entry.image != nil ? .white : .primary)
        .containerBackground(for: .widget) {
            // The background spans the whole widget, so the legibility
            // gradient lives here rather than inside the inset content.
            if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .overlay {
                        LinearGradient(colors: [.clear, .black.opacity(0.8)],
                                       startPoint: .center, endPoint: .bottom)
                    }
            } else {
                Color(.secondarySystemBackground)
            }
        }
    }

    /// Photo column width for the medium widget: as wide as the photo's
    /// aspect ratio needs at full height, capped at half the widget so the
    /// text keeps room.
    /// Distance from the widget's left edge to the name overlay.
    private static let mediumNameInset: CGFloat = 10

    private func mediumPhotoWidth(widgetSize: CGSize) -> CGFloat {
        let aspect: CGFloat
        if let image = entry.image, image.size.height > 0 {
            aspect = image.size.width / image.size.height
        } else {
            aspect = 4 / 3
        }
        return min(widgetSize.height * aspect, widgetSize.width * 0.5)
    }

    private var medium: some View {
        GeometryReader { geometry in
            // Content is inset by the system margins; recover the full widget
            // size so the text column starts where the background photo ends.
            let widgetSize = CGSize(width: geometry.size.width + margins.leading + margins.trailing,
                                    height: geometry.size.height + margins.top + margins.bottom)
            HStack(spacing: 12) {
                // The name sits over the photo, as in the small size, so the
                // text column is not squeezed into truncating it.
                // Sit closer to the widget edge than the system margin; the
                // photo column is the full-bleed background, so nothing clips.
                let inset = max(0, margins.leading - Self.mediumNameInset)
                nameOverlay
                    .frame(width: max(0, mediumPhotoWidth(widgetSize: widgetSize) - Self.mediumNameInset - 6))
                    .frame(maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, -inset)
                VStack(alignment: .leading, spacing: 4) {
                    if entry.ranked.count > 1 {
                        Text("Recently Heard")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        runnersUp(limit: 3)
                    }
                    detailBlock
                    Spacer(minLength: 0)
                    staleLine
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(for: .widget) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    fullBleedPhoto
                        .frame(width: mediumPhotoWidth(widgetSize: geometry.size))
                    Color(.systemBackground)
                }
            }
        }
    }

    /// The whole photo, fitted and centered, over a blurred fill of itself
    /// so the column reaches the widget edges without cropping the bird.
    private var fullBleedPhoto: some View {
        Color.clear
            .overlay {
                if let image = entry.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 14)
                        .overlay(Color.black.opacity(0.12))
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                    LinearGradient(colors: [.clear, .black.opacity(0.8)],
                                   startPoint: .center, endPoint: .bottom)
                } else {
                    Color(.tertiarySystemFill)
                    Image(systemName: entry.headline == nil ? messageSymbol : "bird")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
            .clipped()
    }

    /// Common and scientific names for the medium photo column.
    private var nameOverlay: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let headline = entry.headline {
                Text(headline.commonName)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(headline.scientificName)
                    .font(.caption2)
                    .italic()
                    .lineLimit(2)
                    .opacity(0.85)
            } else {
                Label(messageTitle, systemImage: messageSymbol)
                    .font(.headline)
            }
        }
        .foregroundStyle(entry.image != nil ? .white : .primary)
    }

    /// State text for the medium detail column, when there is any.
    private var detailBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                photo
                    .frame(width: 120, height: 90)
                VStack(alignment: .leading, spacing: 3) {
                    headlineBlock
                    staleLine
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if entry.ranked.count > 1 {
                Divider()
                Text("Also heard")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                runnersUp(limit: 6)
            }
            Spacer(minLength: 0)
        }
        .containerBackground(.background, for: .widget)
    }

    /// A clear container sized by its frame modifiers, with the image laid
    /// over it. Placing a fill-scaled image directly in the stack would let
    /// the image's own size grow the stack and overflow the widget.
    private var photo: some View {
        Color.clear
            .overlay {
                if let image = entry.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.tertiarySystemFill)
                    Image(systemName: entry.headline == nil ? messageSymbol : "bird")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(.rect(cornerRadius: 12))
    }

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let headline = entry.headline {
                Text(headline.commonName)
                    .font(.headline)
                    .lineLimit(2)
                Text(headline.scientificName)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text(messageTitle)
                    .font(.headline)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private func runnersUp(limit: Int) -> some View {
        let rows = entry.ranked.dropFirst().prefix(limit)
        let top = entry.ranked.first?.count ?? 1
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(rows) { species in
                HStack(spacing: 6) {
                    Text(species.commonName)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(species.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if family == .systemLarge || family == .systemExtraLarge {
                    ProgressView(value: Double(species.count), total: Double(max(top, 1)))
                        .tint(.secondary)
                        .controlSize(.mini)
                }
            }
        }
    }

    // MARK: - Lock Screen

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -2) {
                Image(systemName: "bird.fill")
                    .font(.title3)
                if let headline = entry.headline, entry.state == .ranked {
                    Text("\(headline.count)")
                        .font(.caption.bold().monospacedDigit())
                }
            }
            .widgetAccentable()
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let headline = entry.headline {
                Text(headline.commonName)
                    .font(.headline)
                    .lineLimit(1)
                    .widgetAccentable()
                if let shortSubtitle {
                    Text(shortSubtitle)
                        .font(.caption2)
                }
                Text(headline.scientificName)
                    .font(.caption2)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Label(messageTitle, systemImage: messageSymbol)
                    .font(.headline)
                    .widgetAccentable()
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Group {
            if let headline = entry.headline {
                if let shortSubtitle {
                    Label("\(headline.commonName) · \(shortSubtitle)", systemImage: "bird.fill")
                } else {
                    Label(headline.commonName, systemImage: "bird.fill")
                }
            } else {
                Label(messageTitle, systemImage: messageSymbol)
            }
        }
    }

    // MARK: - Text

    private var messageTitle: String {
        switch entry.state {
        case .unconfigured: String(localized: "Not set up")
        case .unavailable: String(localized: "Unreachable")
        case .quiet: String(localized: "Quiet")
        case .ranked: ""
        }
    }

    private var messageSymbol: String {
        switch entry.state {
        case .unconfigured: "gearshape"
        case .unavailable: "wifi.exclamationmark"
        case .quiet, .ranked: "waveform"
        }
    }

    /// Explanatory line for states other than a normal ranking.
    private var subtitle: String? {
        switch entry.state {
        case .unconfigured:
            String(localized: "Open birdo to connect to your BirdNET-Go server.")
        case .unavailable:
            String(localized: "Couldn't reach \(entry.host).")
        case .quiet:
            if let headline = entry.headline {
                String(localized: "Quiet for \(entry.windowMinutes) min · last heard \(timeText(headline.lastHeard))")
            } else {
                String(localized: "Nothing heard in the last \(entry.windowMinutes) min")
            }
        case .ranked:
            nil
        }
    }

    private var shortSubtitle: String? {
        switch entry.state {
        case .ranked:
            nil
        case .quiet:
            if let headline = entry.headline {
                String(localized: "last \(timeText(headline.lastHeard))")
            } else {
                String(localized: "quiet")
            }
        case .unconfigured, .unavailable:
            messageTitle
        }
    }

    @ViewBuilder
    private var staleLine: some View {
        if entry.isStale && entry.state != .unavailable {
            Label(String(localized: "as of \(timeText(entry.asOf))"), systemImage: "exclamationmark.triangle")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

#Preview("Small", as: .systemSmall) {
    TopBirdWidget()
} timeline: {
    TopBirdEntry.sample
}

#Preview("Medium", as: .systemMedium) {
    TopBirdWidget()
} timeline: {
    TopBirdEntry.sample
}
