import Foundation

public final class StyleSelectionModel {
    public private(set) var presets: [StylePreset]
    public private(set) var selectedIndex: Int

    public init(presets: [StylePreset] = BuiltInPresets.all, selectedIndex: Int = 0) {
        precondition(!presets.isEmpty, "StyleSelectionModel requires at least one preset.")
        self.presets = presets
        self.selectedIndex = min(max(0, selectedIndex), presets.count - 1)
    }

    public var selectedPreset: StylePreset {
        presets[selectedIndex]
    }

    public func selectNext() {
        selectedIndex = (selectedIndex + 1) % presets.count
    }

    public func selectPrevious() {
        selectedIndex = (selectedIndex - 1 + presets.count) % presets.count
    }

    public func selectPreset(id: StylePreset.ID) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else {
            return
        }
        selectedIndex = index
    }

    public func replaceSelectedPreset(with preset: StylePreset) {
        presets[selectedIndex] = preset
    }

    public func appendAndSelect(_ preset: StylePreset) {
        presets.append(preset)
        selectedIndex = presets.count - 1
    }

    public func relativeOffset(for preset: StylePreset) -> Int? {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else {
            return nil
        }

        let raw = index - selectedIndex
        let count = presets.count
        if raw > count / 2 { return raw - count }
        if raw < -count / 2 { return raw + count }
        return raw
    }
}
