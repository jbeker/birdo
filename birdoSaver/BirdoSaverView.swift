//
//  BirdoSaverView.swift
//  birdoSaver
//
//  Principal class of the screen saver. Hosts the SwiftUI scene and owns
//  the per-screen model; macOS instantiates one of these per display plus
//  one for the System Settings preview.
//

import OSLog
import ScreenSaver
import SwiftUI

private let log = Logger(subsystem: "com.picosphere.birdo.saver", category: "saver")

// The @objc name must stay un-namespaced: NSPrincipalClass in Info.plist
// is looked up without the Swift module prefix.
@objc(BirdoSaverView)
final class BirdoSaverView: ScreenSaverView {
    private let model = SaverModel()
    private var sheetController: ConfigSheetController?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        wantsLayer = true
        let host = NSHostingView(rootView: SaverRootView(model: model))
        host.frame = bounds
        host.autoresizingMask = [.width, .height]
        addSubview(host)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func startAnimation() {
        super.startAnimation()
        model.start(canvasSize: bounds.size)
    }

    override func stopAnimation() {
        super.stopAnimation()
        // The legacyScreenSaver host outlives the saver session; without
        // this the SSE connection would stream forever.
        model.stop()
    }

    // SwiftUI/Core Animation drive all motion; nothing to draw per frame.
    override func animateOneFrame() {}

    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        log.info("configureSheet requested")
        // Fresh controller per presentation so the field re-reads defaults.
        let controller = ConfigSheetController()
        sheetController = controller
        return controller.window
    }
}
