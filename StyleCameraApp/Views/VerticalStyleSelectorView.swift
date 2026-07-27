import StyleCameraCore
import SwiftUI

struct VerticalStyleSelectorView: View {
    let presets: [StylePreset]
    let selectedID: StylePreset.ID
    let relativeOffset: (StylePreset) -> Int?
    let select: (StylePreset.ID) -> Void
    let selectNext: () -> Void
    let selectPrevious: () -> Void
    let editCurrent: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(visiblePresets) { preset in
                styleButton(for: preset)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    if value.translation.height < 0 {
                        selectNext()
                    } else {
                        selectPrevious()
                    }
                }
        )
    }

    private var visiblePresets: [StylePreset] {
        presets.filter { preset in
            guard let offset = relativeOffset(preset) else { return false }
            return abs(offset) <= 2
        }
    }

    private func styleButton(for preset: StylePreset) -> some View {
        let offset = relativeOffset(preset) ?? 0
        let selected = preset.id == selectedID
        let diameter: CGFloat = selected ? 56 : (abs(offset) == 1 ? 44 : 36)

        return Button {
            select(preset.id)
        } label: {
            Text(label(for: preset))
                .font(.system(size: selected ? 15 : 11, weight: selected ? .bold : .medium))
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .foregroundStyle(selected ? .yellow : .white.opacity(abs(offset) == 2 ? 0.72 : 0.92))
                .frame(width: diameter, height: diameter)
                .background(.black.opacity(selected ? 0.62 : 0.46), in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(selected ? 0.16 : 0.08), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in
                    if selected { editCurrent() }
                }
        )
    }

    private func label(for preset: StylePreset) -> String {
        switch preset.name {
        case "原图": return "原"
        case "食物 ins 风": return "食物"
        case "冷白皮风": return "冷白"
        case "富士清新风": return "富士"
        case "城市质感风": return "城市"
        case "日系奶油风": return "奶油"
        case "夜景氛围风": return "夜景"
        default: return String(preset.name.prefix(2))
        }
    }
}
