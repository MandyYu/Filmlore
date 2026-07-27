import CoreGraphics

public enum ZoomFactorMapper {
    public static func hardwareZoom(
        displayedZoom: CGFloat,
        normalLensHardwareZoom: CGFloat,
        minHardwareZoom: CGFloat,
        maxHardwareZoom: CGFloat
    ) -> CGFloat {
        let normalizedBase = max(1, normalLensHardwareZoom)
        let lowerBound = min(minHardwareZoom, maxHardwareZoom)
        let upperBound = max(minHardwareZoom, maxHardwareZoom)
        let requestedZoom = max(0, displayedZoom) * normalizedBase
        return min(max(requestedZoom, lowerBound), upperBound)
    }
}
