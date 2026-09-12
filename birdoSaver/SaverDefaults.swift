//
//  SaverDefaults.swift
//  birdoSaver
//
//  The saver cannot read the app's preferences (it runs sandboxed inside
//  legacyScreenSaver.appex), so it keeps its own server address via
//  ScreenSaverDefaults. Read fresh at every startAnimation — the host
//  process is long-lived and caches nothing for us.
//

import ScreenSaver

enum SaverDefaults {
    private static let moduleName = "com.picosphere.birdo.saver"
    private static let serverKey = "serverBaseURL"

    private static var store: ScreenSaverDefaults? {
        ScreenSaverDefaults(forModuleWithName: moduleName)
    }

    static var serverBaseURL: URL? {
        guard let stored = store?.string(forKey: serverKey), !stored.isEmpty else { return nil }
        return URL(string: stored)
    }

    static func setServerBaseURL(_ url: URL) {
        guard let store else { return }
        store.set(url.absoluteString, forKey: serverKey)
        store.synchronize()
    }
}
