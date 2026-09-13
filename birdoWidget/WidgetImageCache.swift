//
//  WidgetImageCache.swift
//  birdoWidget
//
//  Species photos, downloaded once and kept in the app group container.
//  Widget views cannot load images asynchronously, so the timeline provider
//  resolves the image up front.
//

import UIKit

enum WidgetImageCache {
    /// Longest edge kept on disk; anything larger is downscaled so the
    /// widget stays within its memory budget.
    private static let maxPixels: CGFloat = 640

    private static var directory: URL {
        let root = AppGroup.containerURL
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = root.appending(path: "SpeciesImages", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func fileURL(for scientificName: String) -> URL {
        let safe = scientificName.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "_" }
        return directory.appending(path: String(safe) + ".jpg")
    }

    static func cachedImage(for scientificName: String) -> UIImage? {
        UIImage(contentsOfFile: fileURL(for: scientificName).path)
    }

    /// Cached image, or a fresh download when `allowNetwork` is set.
    static func image(for scientificName: String, base: URL, session: URLSession,
                      allowNetwork: Bool = true) async -> UIImage? {
        if let cached = cachedImage(for: scientificName) {
            return cached
        }
        guard allowNetwork, let url = DetectionQuery.imageURL(for: scientificName, base: base) else { return nil }
        guard let data = await download(url, session: session),
              var image = UIImage(data: data)
        else { return nil }
        var bytes = data
        let longest = max(image.size.width, image.size.height) * image.scale
        if longest > maxPixels {
            let scale = maxPixels / longest
            let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            if let small = await image.byPreparingThumbnail(ofSize: target),
               let jpeg = small.jpegData(compressionQuality: 0.8) {
                image = small
                bytes = jpeg
            }
        }
        try? bytes.write(to: fileURL(for: scientificName), options: .atomic)
        return image
    }

    /// The proxy answers 503 with Retry-After while it fetches an image it
    /// has not seen before; one short retry usually gets it.
    private static func download(_ url: URL, session: URLSession) async -> Data? {
        for attempt in 0..<2 {
            guard let (data, response) = try? await session.data(from: url),
                  let http = response as? HTTPURLResponse
            else { return nil }
            if http.statusCode == 200 { return data }
            guard http.statusCode == 503, attempt == 0 else { return nil }
            let retryAfter = Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 5
            try? await Task.sleep(for: .seconds(min(retryAfter, 5)))
        }
        return nil
    }
}
