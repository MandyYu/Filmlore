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
    @State private var name: String
    @State private var params: StyleParams

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
        _name = State(initialValue: preset.isBuiltIn ? "\(preset.name) 副本" : preset.name)
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

        let initialName: String
        if isCreatingNew {
            initialName = "我的风格"
        } else if preset.isBuiltIn {
            initialName = "\(preset.name) 副本"
        } else {
            initialName = preset.name
        }
        _name = State(initialValue: initialName)
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

                Form {
                    Section("风格") {
                        TextField("名称", text: $name)
                    }

                    Section("参数") {
                        signedSlider("曝光", value: $params.exposure)
                        signedSlider("鲜明度", value: $params.brilliance)
                        signedSlider("高光", value: $params.highlights)
                        signedSlider("阴影", value: $params.shadows)
                        signedSlider("对比度", value: $params.contrast)
                        signedSlider("黑点", value: $params.blackPoint)
                        signedSlider("亮度", value: $params.brightness)
                        signedSlider("饱和度", value: $params.saturation)
                        signedSlider("自然饱和度", value: $params.vibrance)
                        signedSlider("色温", value: $params.warmth)
                        signedSlider("色调", value: $params.tint)
                        signedSlider("锐度", value: $params.sharpness)
                        positiveSlider("褪色", value: $params.fade)
                        positiveSlider("颗粒", value: $params.grain)
                        positiveSlider("暗角", value: $params.vignette)
                    }

                    Section {
                        if let saveChanges, !isCreatingNew {
                            Button {
                                saveChanges(preset.id, normalizedName, normalizedParams)
                                dismiss()
                            } label: {
                                Text("保存修改")
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        Button {
                            saveAsNew(normalizedName, normalizedParams)
                            dismiss()
                        } label: {
                            Text(isCreatingNew ? "保存新风格" : "另存为新风格")
                                .frame(maxWidth: .infinity)
                        }
                    } footer: {
                        Text("自定义风格属于 StyleCamera Pro 功能。")
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(isCreatingNew ? "新建风格" : "编辑风格")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var normalizedName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }
        return isCreatingNew ? "我的风格" : preset.name
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

            Text(parameterValueText(value.wrappedValue, range: range))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
        .frame(minHeight: 32)
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
                    .foregroundStyle(.white, .green)

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
