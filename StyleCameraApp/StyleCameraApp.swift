import SwiftUI

@main
struct StyleCameraApp: App {
    @StateObject private var proAccess = ProAccessManager()

    var body: some Scene {
        WindowGroup {
            CameraView()
                .environmentObject(proAccess)
//                .statusBarHidden(true)
//                .persistentSystemOverlays(.hidden)
        }
    }
}
