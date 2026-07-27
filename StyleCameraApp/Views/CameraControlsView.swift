import SwiftUI

struct CameraControlsView: View {
    static let height: CGFloat = 126

    let thumbnail: UIImage?
    let openLibrary: () -> Void
    let captureMode: CaptureMode
    let capture: () -> Void
    let openStylePreview: () -> Void
    let isStyleActive: Bool

    var body: some View {
        ZStack {

            HStack {
                recentPhotoButton

                Spacer()

                shutterButton

                Spacer()

                Button(action: openStylePreview) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(isStyleActive ? .yellow : .white)
                        .frame(width: 56, height: 56)
                        .background(
                            isStyleActive ? .yellow.opacity(0.18) : .white.opacity(0.12),
                            in: Circle()
                        )
                        .overlay {
                            Circle()
                                .stroke(isStyleActive ? .yellow.opacity(0.8) : .clear, lineWidth: 1.5)
                        }
                        .overlay(alignment: .topTrailing) {
                            if isStyleActive {
                                Circle()
                                    .fill(.yellow)
                                    .frame(width: 8, height: 8)
                                    .offset(x: -6, y: 6)
                            }
                        }
                }
                .accessibilityLabel("风格预览")
            }
            .padding(.horizontal, 26)
//            .padding(.top, 12)
//            .padding(.bottom, 18)
        }
        .frame(height: Self.height)
    }

    private var shutterButton: some View {
        Button(action: capture) {
            ZStack {
                Circle()
                    .fill(captureMode == .photo ? .white : .red)
                    .frame(width: captureMode == .photo ? 76 : 66, height: captureMode == .photo ? 76 : 66)

                if captureMode == .video {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.white)
                        .frame(width: 24, height: 24)
                }
            }
            .frame(width: 86, height: 86)
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.24), lineWidth: 10)
                    .frame(width: 76, height: 76)
            }
        }
        .buttonStyle(.plain)
    }

    private var recentPhotoButton: some View {
        Button(action: openLibrary) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [.blue.opacity(0.65), .brown.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(Circle())
        }
    }

}
