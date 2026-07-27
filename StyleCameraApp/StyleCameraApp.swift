import SwiftUI

@main
struct StyleCameraApp: App {
    var body: some Scene {
        WindowGroup {
            CameraView()
//                .statusBarHidden(true)
//                .persistentSystemOverlays(.hidden)
        }
    }
}
