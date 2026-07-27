import StyleCameraCore
import SwiftUI

struct StyleEditorView: View {
    let preset: StylePreset
    let save: (String, StyleParams) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var params: StyleParams

    init(
        preset: StylePreset,
        save: @escaping (String, StyleParams) -> Void
    ) {
        self.preset = preset
        self.save = save
        _name = State(initialValue: preset.isBuiltIn ? "\(preset.name) 副本" : preset.name)
        _params = State(initialValue: preset.params)
    }

    var body: some View {
        NavigationStack {
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
                    Button {
                        save(name, normalizedParams)
                        dismiss()
                    } label: {
                        Text("保存为我的风格")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("编辑风格")
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(Int(value.wrappedValue.rounded()).formatted())
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding<Double>(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Float($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            )
        }
    }
}
