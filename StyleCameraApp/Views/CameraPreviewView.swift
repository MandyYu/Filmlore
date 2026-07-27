import SwiftUI

struct CameraPreviewView: View {
    @ObservedObject var store: CameraPreviewStore

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image = store.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [.black, Color(white: 0.18), .black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    ProgressView()
                        .tint(.white)
                }
            }
        }
    }
}
