import StyleCameraCore
import SwiftUI
import UIKit

struct StyleEditorView: View {
    let preset: StylePreset
    let previewStore: CameraPreviewStore?
    let isCreatingNew: Bool
    let saveChanges: ((StylePreset.ID, String, StyleParams) -> Void)?
    let saveAsNew: (String, StyleParams) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var newStyleName: String
    @State private var params: StyleParams
    @State private var isShowingNamePrompt = false

    init(
        preset: StylePreset,
        previewStore: CameraPreviewStore? = nil,
        save: @escaping (String, StyleParams) -> Void
    ) {
        self.preset = preset
        self.previewStore = previewStore
        isCreatingNew = true
        saveChanges = nil
        saveAsNew = save
        _newStyleName = State(initialValue: "\(preset.name) 副本")
        _params = State(initialValue: preset.params)
    }

    init(
        preset: StylePreset,
        previewStore: CameraPreviewStore? = nil,
        isCreatingNew: Bool,
        saveChanges: ((StylePreset.ID, String, StyleParams) -> Void)?,
        saveAsNew: @escaping (String, StyleParams) -> Void
    ) {
        self.preset = preset
        self.previewStore = previewStore
        self.isCreatingNew = isCreatingNew
        self.saveChanges = saveChanges
        self.saveAsNew = saveAsNew

        let suggestedName: String
        if isCreatingNew {
            suggestedName = "我的风格"
        } else {
            suggestedName = "\(preset.name) 副本"
        }
        _newStyleName = State(initialValue: suggestedName)
        _params = State(initialValue: preset.params)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let previewStore {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("实时效果")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)

                        StyleEditorLivePreview(
                            sourceStore: previewStore,
                            params: params
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 12)

                    Divider()
                }

                ScrollView {
                    VStack(spacing: 16) {
                        StyleParameterControls(params: $params)

                        Button(action: requestSaveAsNew) {
                            Text("另存为新风格")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    StyleCameraTheme.primaryGradient,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)

                        Text("自定义风格属于 StyleCamera Pro 功能。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .scrollIndicators(.hidden)
            }
            .background(StyleCameraTheme.screenGradient)
            .tint(StyleCameraTheme.primary)
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("关闭")
                }

                ToolbarItem(placement: .principal) {
                    Text("编辑风格")
                        .font(.headline)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: saveCurrentStyle) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("保存")
                }
            }
//            .toolbarBackground(StyleCameraTheme.screenBackground, for: .navigationBar)
//            .toolbarBackground(.visible, for: .navigationBar)
            .alert("另存为新风格", isPresented: $isShowingNamePrompt) {
                TextField("风格名称", text: $newStyleName)
                Button("取消", role: .cancel) {}
                Button("保存", action: saveNamedStyle)
            } message: {
                Text("输入一个便于识别的风格名称")
            }
        }
    }

    private var normalizedNewStyleName: String {
        let trimmedName = newStyleName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }
        return "我的风格"
    }

    private var normalizedParams: StyleParams {
        StyleParams(
            exposure: params.exposure,
            brilliance: params.brilliance,
            highlights: params.highlights,
            shadows: params.shadows,
            contrast: params.contrast,
            blackPoint: params.blackPoint,
            brightness: params.brightness,
            saturation: params.saturation,
            vibrance: params.vibrance,
            warmth: params.warmth,
            tint: params.tint,
            sharpness: params.sharpness,
            fade: params.fade,
            grain: params.grain,
            vignette: params.vignette
        )
    }

    private func saveCurrentStyle() {
        guard let saveChanges, !isCreatingNew else {
            requestSaveAsNew()
            return
        }

        saveChanges(preset.id, preset.name, normalizedParams)
        dismiss()
    }

    private func requestSaveAsNew() {
        isShowingNamePrompt = true
    }

    private func saveNamedStyle() {
        saveAsNew(normalizedNewStyleName, normalizedParams)
        dismiss()
    }
}

private struct StyleParameterControls: View {
    @Binding var params: StyleParams

    var body: some View {
        VStack(spacing: 0) {
            signedSlider("曝光", value: $params.exposure)
            divider
            signedSlider("鲜明度", value: $params.brilliance)
            divider
            signedSlider("高光", value: $params.highlights)
            divider
            signedSlider("阴影", value: $params.shadows)
            divider
            signedSlider("对比度", value: $params.contrast)
            divider
            signedSlider("黑点", value: $params.blackPoint)
            divider
            signedSlider("亮度", value: $params.brightness)
            divider
            signedSlider("饱和度", value: $params.saturation)
            divider
            signedSlider("自然饱和度", value: $params.vibrance)
            divider
            signedSlider("色温", value: $params.warmth)
            divider
            signedSlider("色调", value: $params.tint)
            divider
            signedSlider("锐度", value: $params.sharpness)
            divider
            positiveSlider("褪色", value: $params.fade)
            divider
            positiveSlider("颗粒", value: $params.grain)
            divider
            positiveSlider("暗角", value: $params.vignette)
        }
        .padding(.horizontal, 14)
        .background(
            StyleCameraTheme.panelBackground,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var divider: some View {
        Divider()
            .overlay(StyleCameraTheme.divider.opacity(0.45))
    }

    private func signedSlider(_ title: String, value: Binding<Float>) -> some View {
        parameterSlider(title, value: value, range: -100...100)
    }

    private func positiveSlider(_ title: String, value: Binding<Float>) -> some View {
        parameterSlider(title, value: value, range: 0...100)
    }

    private func parameterSlider(
        _ title: String,
        value: Binding<Float>,
        range: ClosedRange<Float>
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: 82, alignment: .leading)

            Slider(
                value: Binding<Double>(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Float($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
            .accessibilityLabel(title)
            .tint(StyleCameraTheme.primaryGradient)

            Text(parameterValueText(value.wrappedValue, range: range))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
        .frame(minHeight: 42)
    }

    private func parameterValueText(
        _ value: Float,
        range: ClosedRange<Float>
    ) -> String {
        let roundedValue = Int(value.rounded())
        if range.lowerBound < 0, roundedValue > 0 {
            return "+\(roundedValue)"
        }
        return "\(roundedValue)"
    }
}

private struct StyleEditorLivePreview: View {
    @ObservedObject var sourceStore: CameraPreviewStore
    let params: StyleParams

    @StateObject private var renderer = StyleEditorPreviewModel()
    @GestureState private var isShowingOriginal = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black

            if let image = displayedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                ProgressView("正在连接实时画面…")
                    .tint(.white)
                    .foregroundStyle(.white)
            }

            HStack {
                Label("实时预览", systemImage: "circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, StyleCameraTheme.cyan)

                Spacer()

                Text(isShowingOriginal ? "原图" : "按住对比")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 11)
                    .frame(height: 32)
                    .background(.black.opacity(0.52), in: Capsule())
                    .contentShape(Rectangle())
                    .gesture(compareGesture)
            }
            .font(.caption)
            .foregroundStyle(.white)
            .padding(12)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.58)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            renderer.update(source: sourceStore.image, params: params)
        }
        .onReceive(sourceStore.$image) { image in
            renderer.update(source: image, params: params)
        }
        .onChange(of: params) { _, updatedParams in
            renderer.update(source: sourceStore.image, params: updatedParams)
        }
    }

    private var displayedImage: UIImage? {
        if isShowingOriginal {
            return sourceStore.image
        }
        return renderer.image
    }

    private var compareGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isShowingOriginal) { _, isShowingOriginal, _ in
                isShowingOriginal = true
            }
    }
}

@MainActor
private final class StyleEditorPreviewModel: ObservableObject {
    @Published private(set) var image: UIImage?

    private let worker = StyleEditorPreviewWorker()
    private let queue = DispatchQueue(
        label: "stylecamera.style.editor.preview.queue",
        qos: .userInitiated
    )
    private var latestSource: UIImage?
    private var latestParams = StyleParams()
    private var generation = 0
    private var isRendering = false

    func update(source: UIImage?, params: StyleParams) {
        latestSource = source
        latestParams = params
        generation += 1
        renderIfNeeded()
    }

    private func renderIfNeeded() {
        guard !isRendering, let source = latestSource else { return }

        isRendering = true
        let requestedGeneration = generation
        let params = latestParams
        let worker = worker

        queue.async { [weak self] in
            let image = worker.render(source: source, params: params)

            Task { @MainActor in
                guard let self else { return }
                self.isRendering = false
                self.image = image

                if requestedGeneration != self.generation {
                    self.renderIfNeeded()
                }
            }
        }
    }
}

private final class StyleEditorPreviewWorker: @unchecked Sendable {
    private let renderer = StyleRenderer()
    private let maximumPreviewDimension: CGFloat = 1_000

    func render(source: UIImage, params: StyleParams) -> UIImage? {
        guard var input = CIImage(image: source) else { return nil }

        input = renderer.normalized(input)
        let longestSide = max(input.extent.width, input.extent.height)
        if longestSide > maximumPreviewDimension {
            let scale = maximumPreviewDimension / longestSide
            input = input.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        let output = renderer.applyStyle(to: input, params: params)
        guard let cgImage = renderer.context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}
