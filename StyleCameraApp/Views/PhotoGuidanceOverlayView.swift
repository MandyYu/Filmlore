import StyleCameraCore
import SwiftUI

struct PhotoGuidanceOverlayView: View {
    let hint: PhotoGuidanceHint?

    var body: some View {
        Group {
            if let hint {
                HStack(spacing: 8) {
                    Image(systemName: iconName(for: hint.category))
                        .font(.system(size: 13, weight: .semibold))

                    Text(hint.message)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .foregroundStyle(foregroundColor(for: hint))
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(StyleCameraTheme.panelBackground.opacity(0.84), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(StyleCameraTheme.primary.opacity(0.32), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 4)
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: hint?.message)
    }

    private func iconName(for category: PhotoGuidanceCategory) -> String {
        switch category {
        case .composition: return "viewfinder"
        case .angle: return "gyroscope"
        case .light: return "sun.max.fill"
        case .sharpness: return "hand.raised.fill"
        case .style: return "sparkles"
        }
    }

    private func foregroundColor(for hint: PhotoGuidanceHint) -> Color {
        switch hint.severity {
        case .high: return StyleCameraTheme.orange
        case .medium: return .white
        case .low: return StyleCameraTheme.palePink
        }
    }
}
