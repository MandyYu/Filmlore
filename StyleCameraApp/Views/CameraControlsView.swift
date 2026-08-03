import SwiftUI

struct CameraControlsView: View {
    static let height: CGFloat = 106

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
                    Image(systemName: "camera.filters")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(isStyleActive ? StyleCameraTheme.primary : .white)
                        .frame(width: 54, height: 54)
                        .background(
                            isStyleActive
                                ? StyleCameraTheme.primary.opacity(0.2)
                                : StyleCameraTheme.elevatedBackground.opacity(0.88),
                            in: Circle()
                        )
                        .overlay {
                            Circle()
                                .stroke(
                                    isStyleActive ? StyleCameraTheme.primary.opacity(0.9) : .clear,
                                    lineWidth: 1.5
                                )
                        }
//                        .overlay(alignment: .topTrailing) {
//                            if isStyleActive {
//                                Circle()
//                                    .fill(StyleCameraTheme.coral)
//                                    .frame(width: 8, height: 8)
//                                    .offset(x: -6, y: 6)
//                            }
//                        }
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
                    .fill(captureMode == .photo ? .white : StyleCameraTheme.primary)
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
//                    .stroke(
//                           captureMode == .photo
//                               ? StyleCameraTheme.primary.opacity(0.9)
//                               : StyleCameraTheme.palePink.opacity(0.5),
//                           lineWidth: 5
//                       )
                    .stroke(shutterRingStyle, lineWidth: 5)
                    .frame(width: 76, height: 76)
            }
        }
        .buttonStyle(.plain)
    }

    private var shutterRingStyle: AnyShapeStyle {
        if captureMode == .photo {
            return AnyShapeStyle(StyleCameraTheme.shutterRingGradient)
        }
        return AnyShapeStyle(StyleCameraTheme.palePink.opacity(0.5))
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
                        colors: [StyleCameraTheme.deepPurple, StyleCameraTheme.coral],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(
                Circle()
            )
            .overlay {
                Circle()
                    .stroke(StyleCameraTheme.primary.opacity(0.6), lineWidth: 1.5)
            }
        }
    }

}
