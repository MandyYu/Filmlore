import AVFoundation
import StyleCameraCore
import Foundation
import PhotosUI
import SwiftUI
import UIKit

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @State private var isLensDialVisible = false
    @State private var isStylePreviewVisible = false
    @State private var isAspectRatioPickerVisible = false
    @State private var focusIndicator: FocusIndicator?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    cameraStage
                        .contentShape(Rectangle())

                    CameraControlsView(
                        thumbnail: viewModel.lastSavedThumbnail,
                        openLibrary: viewModel.openPhotoLibrary,
                        captureMode: viewModel.captureMode,
                        capture: viewModel.capturePrimaryAction,
                        openStylePreview: openStylePreview,
                        isStyleActive: isStyleActive
                    )
                }
//                .padding(.top, proxy.safeAreaInsets.top)
//                .padding(.bottom, proxy.safeAreaInsets.bottom)

                if isStylePreviewVisible {
                    VStack {
                        Spacer()

                        StylePreviewComparisonView(
                            presets: viewModel.selection.presets,
                            selectedID: viewModel.selection.selectedPreset.id,
                            previewStore: viewModel.stylePreviewStore,
                            select: { id in
                                viewModel.selectStyle(id: id)
                            }
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, CameraControlsView.height )
                        .simultaneousGesture(stylePreviewDismissGesture)
                    }
                    .zIndex(4)
                }

                if isAspectRatioPickerVisible {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: proxy.safeAreaInsets.top)
                            .allowsHitTesting(false)

                        CaptureAspectRatioPickerView(
                            selected: viewModel.captureAspectRatio,
                            select: { ratio in
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                    viewModel.setCaptureAspectRatio(ratio)
                                    isAspectRatioPickerVisible = false
                                }
                            }
                        )
                        .padding(.horizontal, 52)
                        .padding(.top, 4)

                        Spacer()
                    }
                    .zIndex(5)
                }

            }
        }
        .sheet(isPresented: $viewModel.isStyleEditorPresented) {
            StyleEditorView(
                preset: viewModel.selection.selectedPreset,
                save: viewModel.saveCustomStyle
            )
        }
        .sheet(isPresented: $viewModel.isPhotoLibraryPresented) {
            PhotoLibraryPickerView { image in
                viewModel.useLibraryImage(image)
            }
        }
        .sheet(isPresented: $viewModel.isSettingsPresented) {
            CameraSettingsView(
                watermark: $viewModel.watermark,
                photoFrame: $viewModel.photoFrame,
                guidanceSettings: $viewModel.guidanceSettings,
                currentStyleName: viewModel.selection.selectedPreset.name,
                locationText: viewModel.locationText,
                requestLocation: viewModel.requestWatermarkLocation
            )
            .presentationDetents([.medium, .large])
        }
        .onAppear(perform: viewModel.start)
        .onDisappear(perform: viewModel.stop)
    }

    private func openStylePreview() {
        guard !isStylePreviewVisible else {
            closeStylePreview()
            return
        }

        isAspectRatioPickerVisible = false
        viewModel.setStylePreviewComparisonActive(true)
        isStylePreviewVisible = true
    }

    private func closeStylePreview() {
        viewModel.setStylePreviewComparisonActive(false)
        isStylePreviewVisible = false
    }

    private var stylePreviewDismissGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                let verticalDistance = value.translation.height
                let horizontalDistance = abs(value.translation.width)
                guard verticalDistance > 44, verticalDistance > horizontalDistance else { return }

                withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                    closeStylePreview()
                }
            }
    }

    private var isStyleActive: Bool {
        viewModel.selection.selectedPreset.id != BuiltInPresets.original.id
    }

    private var topControlLayer: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [
//                        .black.opacity(0.96),
//                        .black.opacity(0.74),
                        .black.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: topControlHeight)
                .allowsHitTesting(false)

                topBar()
                    .padding(.top, topBarTopPadding)
            }

            Spacer()
        }
    }

    private var topControlHeight: CGFloat { 126 }
    private var topBarTopPadding: CGFloat { 8 }
    private var topBarHeight: CGFloat { 44 }
    private var guidanceTopPadding: CGFloat { 20 }
    private var minimumGuidanceTopOffset: CGFloat {
        topBarTopPadding + topBarHeight + guidanceTopPadding
    }

    private var cameraStage: some View {
        GeometryReader { proxy in
            let surfaceSize = previewSurfaceSize(in: proxy.size)
            let previewTopOffset = (proxy.size.height - surfaceSize.height) / 2
            let guidanceTopOffset = max(previewTopOffset + guidanceTopPadding, minimumGuidanceTopOffset)

            ZStack {
                Color.black

                cameraPreviewLayer(surfaceSize: surfaceSize)
                    .frame(width: surfaceSize.width, height: surfaceSize.height)
                    .clipped()
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .animation(.spring(response: 0.28, dampingFraction: 0.88), value: viewModel.captureAspectRatio)
                    .zIndex(0)

                guidanceOverlay(topOffset: guidanceTopOffset)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                    .zIndex(1)

                cameraControlLayer
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .zIndex(2)
            }
            .clipped()
        }
    }

    private func cameraPreviewLayer(surfaceSize: CGSize) -> some View {
        ZStack {
            CameraPreviewView(store: viewModel.previewStore)
                .overlay(previewOverlayLayer)
                .contentShape(Rectangle())
                .gesture(focusTapGesture(in: surfaceSize))

            if let focusIndicator {
                FocusReticleView()
                    .position(focusIndicator.location)
                    .id(focusIndicator.id)
                    .transition(.scale(scale: 1.18).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
    }

    private func guidanceOverlay(topOffset: CGFloat) -> some View {
        VStack {
            PhotoGuidanceOverlayView(hint: viewModel.guidanceHint)
            Spacer()
        }
        .padding(.top, topOffset)
        .padding(.horizontal, 18)
        .allowsHitTesting(false)
    }

    private var cameraControlLayer: some View {
        ZStack {
            topControlLayer

            VStack(spacing: 8) {
                Spacer()

                lensControl

                modeSelector
//                    .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private var lensControl: some View {
        if isLensDialVisible {
            LensDialView(
                zoom: viewModel.selectedLens,
                setZoom: viewModel.setZoom,
                finish: {
                    withAnimation(.easeOut(duration: 0.18)) {
                        isLensDialVisible = false
                    }
                }
            )
            .frame(height: 152)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .padding(.bottom, -18)
        } else {
            lensRow
                .transition(.opacity)
        }
    }

    private func previewSurfaceSize(in availableSize: CGSize) -> CGSize {
        guard availableSize.width > 0, availableSize.height > 0 else {
            return .zero
        }

        let ratio = viewModel.captureAspectRatio.portraitRatio
        return CGSize(width: availableSize.width, height: availableSize.width / ratio)
    }

    @ViewBuilder
    private var previewOverlayLayer: some View {
        ZStack {
            if viewModel.showGrid {
                GridOverlayView()
            }

            LiveFrameOverlayView(preset: viewModel.photoFrame)

            LiveWatermarkOverlayView(
                watermark: viewModel.watermark,
                styleName: viewModel.selection.selectedPreset.name,
                locationText: viewModel.locationText,
                rollDegrees: viewModel.currentRollDegrees,
                updatePosition: viewModel.updateWatermarkAnchor
            )
        }
    }

    private func topBar() -> some View {
        ZStack {
            HStack {
                Button(action: viewModel.flipCamera) {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .foregroundStyle(.white)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.34), in: Circle())
                }

                Spacer()

                HStack(spacing: 16) {
                    Button(action: viewModel.toggleFlash) {
                        FlashModeButtonLabel(mode: viewModel.flashMode)
                    }
                    .accessibilityLabel(viewModel.flashMode.accessibilityTitle)

                    WatermarkToggleButton(
                        isOn: viewModel.watermark.enabled,
                        action: viewModel.toggleWatermark
                    )

                    Button {
                        viewModel.isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
                .foregroundStyle(.white)
                .font(.title3)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(.black.opacity(0.34), in: Capsule())
            }

            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                    isAspectRatioPickerVisible.toggle()
                }
            } label: {
                CaptureAspectRatioTopButton(
                    aspectRatio: viewModel.captureAspectRatio,
                    isExpanded: isAspectRatioPickerVisible
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
//        .padding(.top, safeTopInset + 8)
//        .frame(height: 76 + safeTopInset)
    }

    private var lensRow: some View {
        HStack(spacing: 3) {
            ForEach([1, 2, 5, 10], id: \.self) { lens in
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                        viewModel.setZoom(CGFloat(lens))
                        isLensDialVisible = false
                    }
                } label: {
                    let isSelected = abs(viewModel.selectedLens - CGFloat(lens)) < 0.05

                    Text("\(lens)x")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? .black : .white.opacity(0.68))
                        .frame(width: 36, height: 30)
                        .background(isSelected ? Color.white : Color.clear, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.black.opacity(0.62), in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.22)
                .onEnded { _ in
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
                        isLensDialVisible = true
                    }
                }
        )
        .highPriorityGesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                        isLensDialVisible = true
                    }
                    setZoomFromHorizontalDrag(value)
                }
                .onEnded { value in
                    setZoomFromHorizontalDrag(value)
                    finishLensDial()
                }
        )
        .shadow(radius: 4)
    }

    private func setZoomFromHorizontalDrag(_ value: DragGesture.Value) {
        let screenWidth = max(1, UIScreen.main.bounds.width)
        let usableWidth = screenWidth * 0.62
        let centerX = screenWidth / 2
        let progress = max(0, min(1, (value.location.x - (centerX - usableWidth / 2)) / usableWidth))
        viewModel.setZoom(LensZoomScale.roundedZoom(fromProgress: progress))
    }

    private func finishLensDial() {
        withAnimation(.easeOut(duration: 0.2).delay(0.35)) {
            isLensDialVisible = false
        }
    }

    private var modeSelector: some View {
        HStack(spacing: 28) {
            modeButton(.video)
            modeButton(.photo)
        }
        .font(.title3)
        .frame(height: 52)
    }

    private func modeButton(_ mode: CaptureMode) -> some View {
        Button {
            viewModel.setCaptureMode(mode)
        } label: {
            Text(mode.title)
                .fontWeight(viewModel.captureMode == mode ? .semibold : .regular)
                .foregroundStyle(viewModel.captureMode == mode ? .yellow : .white)
                .frame(width: mode == .video ? 52 : 62, height: 44)
        }
        .buttonStyle(.plain)
    }

    private func focusTapGesture(in surfaceSize: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                focus(at: value.location, in: surfaceSize)
            }
    }

    private func focus(at location: CGPoint, in surfaceSize: CGSize) {
        let clampedLocation = CGPoint(
            x: max(0, min(surfaceSize.width, location.x)),
            y: max(0, min(surfaceSize.height, location.y))
        )
        let point = CGPoint(
            x: max(0, min(1, clampedLocation.x / max(1, surfaceSize.width))),
            y: max(0, min(1, clampedLocation.y / max(1, surfaceSize.height)))
        )
        let indicator = FocusIndicator(location: clampedLocation)

        viewModel.focus(at: point)
        withAnimation(.spring(response: 0.22, dampingFraction: 0.74)) {
            focusIndicator = indicator
        }

        Task { [indicatorID = indicator.id] in
            try? await Task.sleep(nanoseconds: 850_000_000)
            await MainActor.run {
                guard focusIndicator?.id == indicatorID else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    focusIndicator = nil
                }
            }
        }
    }
}

private struct FocusIndicator: Identifiable, Equatable {
    let id = UUID()
    let location: CGPoint
}

private struct FocusReticleView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(.yellow, lineWidth: 1.7)
                .frame(width: 70, height: 70)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(.yellow.opacity(0.72), lineWidth: 1)
                .frame(width: 48, height: 48)
                .opacity(0.42)
        }
        .shadow(color: .black.opacity(0.38), radius: 3, x: 0, y: 1)
    }
}

private extension CaptureMode {
    var title: String {
        switch self {
        case .video: return "视频"
        case .photo: return "照片"
        }
    }
}

private struct FlashModeButtonLabel: View {
    let mode: AVCaptureDevice.FlashMode

    var body: some View {
        Image(systemName: mode.iconName)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(mode.tint)
            .frame(width: 28, height: 44)
    }
}

private extension AVCaptureDevice.FlashMode {
    var iconName: String {
        switch self {
        case .off:
            return "bolt.slash"
        case .auto:
            return "bolt.badge.a"
        case .on:
            return "bolt.fill"
        @unknown default:
            return "bolt.slash"
        }
    }

    var tint: Color {
        switch self {
        case .on:
            return .yellow
        case .auto, .off:
            return .white
        @unknown default:
            return .white
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .off:
            return "闪光灯关闭"
        case .auto:
            return "闪光灯自动"
        case .on:
            return "闪光灯开启"
        @unknown default:
            return "闪光灯"
        }
    }
}

private struct CaptureAspectRatioTopButton: View {
    let aspectRatio: CaptureAspectRatio
    let isExpanded: Bool

    var body: some View {
        Group {
            if isExpanded {
                Image(systemName: "chevron.up")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
//                    .background(.white.opacity(0.18), in: Circle())
            } else {
                Text(aspectRatio.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 38)
//                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .contentShape(Rectangle())
        .accessibilityLabel("图片比例")
    }
}

private struct CaptureAspectRatioPickerView: View {
    let selected: CaptureAspectRatio
    let select: (CaptureAspectRatio) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CaptureAspectRatio.allCases) { aspectRatio in
                Button {
                    select(aspectRatio)
                } label: {
                    VStack(spacing: 8) {
                        ratioIcon(for: aspectRatio)
                            .frame(height: 34)

                        Text(aspectRatio.title)
                            .font(.system(size: 14, weight: selected == aspectRatio ? .semibold : .medium))
                            .foregroundStyle(selected == aspectRatio ? .white : .white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: 540)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.22))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.32), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private func ratioIcon(for aspectRatio: CaptureAspectRatio) -> some View {
        let isSelected = selected == aspectRatio
        let lineWidth: CGFloat = isSelected ? 2.2 : 1.8
        let color = isSelected ? Color.white : Color.white.opacity(0.45)

        switch aspectRatio {
        case .threeByFour:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(color, lineWidth: lineWidth)
                .frame(width: 22, height: 29)
        case .square:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(color, lineWidth: lineWidth)
                .frame(width: 25, height: 25)
        case .nineBySixteen:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(color, lineWidth: lineWidth)
                .frame(width: 19, height: 34)
        }
    }
}

private struct LiveWatermarkOverlayView: View {
    let watermark: WatermarkPreset
    let styleName: String
    let locationText: String?
    let rollDegrees: Double
    let updatePosition: (CGPoint) -> Void
    @State private var displayOrientation: WatermarkDisplayOrientation = .portrait
    @State private var dragStartDisplayAnchor: CGPoint?

    var body: some View {
        GeometryReader { proxy in
            if shouldShowWatermark {
                watermarkContent(in: proxy.size)
                    .rotationEffect(.degrees(displayOrientation.textRotationDegrees))
                    .position(anchorPoint(in: proxy.size))
                    .gesture(
                        DragGesture(minimumDistance: 8, coordinateSpace: .named(Self.dragCoordinateSpace))
                            .onChanged { value in
                                updateWatermarkPosition(for: value, in: proxy.size)
                            }
                            .onEnded { value in
                                updateWatermarkPosition(for: value, in: proxy.size)
                                dragStartDisplayAnchor = nil
                            }
                    )
            }
        }
        .coordinateSpace(name: Self.dragCoordinateSpace)
        .onAppear {
            updateDisplayOrientation(for: rollDegrees)
        }
        .onChange(of: rollDegrees) { _, newValue in
            updateDisplayOrientation(for: newValue)
        }
    }

    private var shouldShowWatermark: Bool {
        guard watermark.enabled else { return false }

        switch watermark.mode {
        case .manual:
            return !displayText.isEmpty
        case .image:
            return watermarkImage != nil
        }
    }

    @ViewBuilder
    private func watermarkContent(in size: CGSize) -> some View {
        switch watermark.mode {
        case .manual:
            watermarkLabel
        case .image:
            if let watermarkImage {
                Image(uiImage: watermarkImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageWatermarkWidth(in: size))
                    .opacity(Double(watermark.opacity))
                    .shadow(color: effectColor, radius: effectRadius, x: 0, y: effectYOffset)
                    .contentShape(Rectangle())
            }
        }
    }

    private var watermarkLabel: some View {
        Text(displayText)
            .font(font)
            .foregroundStyle(foregroundColor)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(backgroundShape)
            .shadow(color: effectColor, radius: effectRadius, x: 0, y: effectYOffset)
            .contentShape(Rectangle())
    }

    private var displayText: String {
        var parts = [String]()
        let text = watermark.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            parts.append(text)
        }
        if watermark.includeStyleName {
            parts.append(styleName)
        }
        if watermark.includeDevice {
            parts.append("iPhone")
        }
        if watermark.includeLocation {
            let overrideText = watermark.locationOverrideText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !overrideText.isEmpty {
                parts.append(overrideText)
            } else if let locationText,
                      !locationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parts.append(locationText)
            }
        }
        if watermark.includeDate {
            parts.append(Self.dateFormatter.string(from: Date()))
        }
        return parts.joined(separator: " · ")
    }

    private var watermarkImage: UIImage? {
        guard let imageData = watermark.imageData else {
            return nil
        }

        return UIImage(data: imageData)
    }

    private func imageWatermarkWidth(in size: CGSize) -> CGFloat {
        max(44, min(size.width, size.height) * CGFloat(watermark.imageScale))
    }

    private var font: Font {
        switch watermark.visualStyle {
        case .film:
            return .system(size: 13, weight: .medium, design: .monospaced)
        case .darkBadge, .lightBadge:
            return .system(size: 14, weight: .semibold)
        case .minimal:
            return .system(size: 14, weight: .medium)
        }
    }

    private var foregroundColor: Color {
        let alpha = Double(watermark.opacity)
        switch watermark.visualStyle {
        case .minimal, .darkBadge:
            return watermark.textColor.previewColor(fallback: .white, opacity: alpha)
        case .lightBadge:
            return watermark.textColor.previewColor(fallback: .black, opacity: alpha * 0.76)
        case .film:
            return watermark.textColor.previewColor(
                fallback: Color(red: 1.0, green: 0.88, blue: 0.36),
                opacity: alpha
            )
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        switch watermark.visualStyle {
        case .minimal:
            Color.clear
        case .darkBadge:
            Capsule().fill(.black.opacity(Double(watermark.opacity) * 0.46))
        case .lightBadge:
            Capsule().fill(.white.opacity(Double(watermark.opacity) * 0.72))
        case .film:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(Double(watermark.opacity) * 0.58))
        }
    }

    private var horizontalPadding: CGFloat {
        watermark.visualStyle == .minimal ? 0 : 12
    }

    private var verticalPadding: CGFloat {
        watermark.visualStyle == .minimal ? 0 : 7
    }

    private var effectColor: Color {
        switch watermark.effect {
        case .none: return .clear
        case .shadow: return .black.opacity(Double(watermark.opacity) * 0.48)
        case .glow: return .white.opacity(Double(watermark.opacity) * 0.64)
        }
    }

    private var effectRadius: CGFloat {
        switch watermark.effect {
        case .none: return 0
        case .shadow: return 8
        case .glow: return 14
        }
    }

    private var effectYOffset: CGFloat {
        watermark.effect == .shadow ? 2 : 0
    }

    private var configuredAnchor: CGPoint {
        switch watermark.position {
        case .topLeft:
            return CGPoint(x: 0.2, y: 0.08)
        case .topRight:
            return CGPoint(x: 0.8, y: 0.08)
        case .bottomLeft:
            return CGPoint(x: 0.2, y: 0.91)
        case .bottomRight:
            return CGPoint(x: 0.78, y: 0.91)
        case .bottomCenter:
            return CGPoint(x: 0.5, y: 0.91)
        case .custom:
            let custom = watermark.customPosition ?? WatermarkAnchor(x: 0.5, y: 0.86)
            return CGPoint(x: CGFloat(custom.x), y: CGFloat(custom.y))
        }
    }

    private var displayAnchor: CGPoint {
        displayOrientation.displayAnchor(from: configuredAnchor)
    }

    private func anchorPoint(in size: CGSize) -> CGPoint {
        let anchor = displayAnchor

        return CGPoint(
            x: max(24, min(size.width - 24, anchor.x * size.width)),
            y: max(24, min(size.height - 24, anchor.y * size.height))
        )
    }

    private func updateWatermarkPosition(for value: DragGesture.Value, in size: CGSize) {
        let startAnchor = dragStartDisplayAnchor ?? displayAnchor
        if dragStartDisplayAnchor == nil {
            dragStartDisplayAnchor = startAnchor
        }

        let draggedAnchor = CGPoint(
            x: startAnchor.x + value.translation.width / max(1, size.width),
            y: startAnchor.y + value.translation.height / max(1, size.height)
        )
        let logicalAnchor = displayOrientation.logicalAnchor(from: draggedAnchor)
        updatePosition(logicalAnchor)
    }

    private static let dragCoordinateSpace = "live-watermark-overlay"

    private func updateDisplayOrientation(for rollDegrees: Double) {
        guard dragStartDisplayAnchor == nil else { return }
        let nextOrientation = WatermarkDisplayOrientation(
            rollDegrees: rollDegrees,
            current: displayOrientation
        )
        guard nextOrientation != displayOrientation else { return }

        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
            displayOrientation = nextOrientation
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}

private enum WatermarkDisplayOrientation: Equatable {
    case portrait
    case landscapeLeft
    case landscapeRight
    case portraitUpsideDown

    init(rollDegrees: Double, current: WatermarkDisplayOrientation) {
        let degrees = Self.normalizedRollDegrees(rollDegrees)
        let absoluteDegrees = abs(degrees)

        if absoluteDegrees >= 135 || (current == .portraitUpsideDown && absoluteDegrees >= 128) {
            self = .portraitUpsideDown
        } else if degrees >= 45 || (current == .landscapeLeft && degrees >= 38) {
            self = .landscapeLeft
        } else if degrees <= -45 || (current == .landscapeRight && degrees <= -38) {
            self = .landscapeRight
        } else {
            self = .portrait
        }
    }

    var textRotationDegrees: Double {
        switch self {
        case .portrait:
            return 0
        case .landscapeLeft:
            return -90
        case .landscapeRight:
            return 90
        case .portraitUpsideDown:
            return 180
        }
    }

    func displayAnchor(from logicalAnchor: CGPoint) -> CGPoint {
        let anchor = clamped(logicalAnchor)
        switch self {
        case .portrait:
            return anchor
        case .landscapeLeft:
            return CGPoint(x: anchor.y, y: 1 - anchor.x)
        case .landscapeRight:
            return CGPoint(x: 1 - anchor.y, y: anchor.x)
        case .portraitUpsideDown:
            return CGPoint(x: 1 - anchor.x, y: 1 - anchor.y)
        }
    }

    func logicalAnchor(from displayAnchor: CGPoint) -> CGPoint {
        let anchor = clamped(displayAnchor)
        switch self {
        case .portrait:
            return anchor
        case .landscapeLeft:
            return CGPoint(x: 1 - anchor.y, y: anchor.x)
        case .landscapeRight:
            return CGPoint(x: anchor.y, y: 1 - anchor.x)
        case .portraitUpsideDown:
            return CGPoint(x: 1 - anchor.x, y: 1 - anchor.y)
        }
    }

    private static func normalizedRollDegrees(_ degrees: Double) -> Double {
        var normalized = degrees.truncatingRemainder(dividingBy: 360)
        if normalized > 180 {
            normalized -= 360
        } else if normalized < -180 {
            normalized += 360
        }
        return normalized
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(1, max(0, point.x)),
            y: min(1, max(0, point.y))
        )
    }
}

private struct LiveFrameOverlayView: View {
    let preset: PhotoFramePreset

    var body: some View {
        GeometryReader { proxy in
            if preset.enabled {
                frameShape(size: proxy.size)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func frameShape(size: CGSize) -> some View {
        switch preset.style {
        case .cleanWhite, .cleanBlack:
            Rectangle()
                .strokeBorder(frameColor.opacity(Double(preset.opacity)), lineWidth: max(12, min(size.width, size.height) * 0.035))
        case .instant:
            ZStack(alignment: .bottom) {
                Rectangle()
                    .strokeBorder(Color.white.opacity(Double(preset.opacity)), lineWidth: max(14, min(size.width, size.height) * 0.045))

                Rectangle()
                    .fill(Color.white.opacity(Double(preset.opacity)))
                    .frame(height: max(56, size.height * 0.12))
                    .overlay(alignment: .topLeading) {
                        Capsule()
                            .fill(.black.opacity(0.12))
                            .frame(width: size.width * 0.34, height: 3)
                            .padding(.top, 18)
                            .padding(.leading, 24)
                    }
            }
        case .film:
            HStack {
                filmRail
                Spacer()
                filmRail
            }
            .background {
                Rectangle()
                    .strokeBorder(Color.black.opacity(Double(preset.opacity) * 0.86), lineWidth: max(12, size.width * 0.028))
            }
        }
    }

    private var frameColor: Color {
        preset.style == .cleanBlack ? .black : .white
    }

    private var filmRail: some View {
        VStack(spacing: 10) {
            ForEach(0..<8, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(.white.opacity(Double(preset.opacity) * 0.24))
                    .frame(width: 8, height: 18)
            }
        }
        .frame(width: 28)
        .background(.black.opacity(Double(preset.opacity) * 0.78))
    }
}

private struct StylePreviewComparisonView: View {
    let presets: [StylePreset]
    let selectedID: StylePreset.ID
    @ObservedObject var previewStore: StylePreviewStore
    let select: (StylePreset.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets) { preset in
                        styleCard(for: preset)
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.black.opacity(0.9))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 8)
    }

    private func styleCard(for preset: StylePreset) -> some View {
        let isSelected = preset.id == selectedID

        return Button {
            select(preset.id)
        } label: {
            VStack(spacing: 7) {
                Text(shortName(for: preset))
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.72))
                    .lineLimit(1)
                    .frame(width: 82)

                ZStack {
                    if let image = previewStore.images[preset.id] {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        LinearGradient(
                            colors: [.black, .white.opacity(0.13), .black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.72)
                    }

                    if isSelected {
                        selectedStyleOverlay
                    }
                }
                .frame(width: 82, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
        .buttonStyle(.plain)
    }

    private var selectedStyleOverlay: some View {
        ZStack {
            Color.black.opacity(0.54)

            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
//                .background(.black.opacity(0.46), in: Circle())
        }
    }

    private func shortName(for preset: StylePreset) -> String {
        switch preset.name {
        case "原图": return "原图"
        case "食物 ins 风": return "食物"
        case "冷白皮风": return "冷白皮"
        case "富士清新风": return "富士"
        case "城市质感风": return "城市"
        case "日系奶油风": return "奶油"
        case "夜景氛围风": return "夜景"
        default: return preset.name
        }
    }
}

private struct CameraSettingsView: View {
    @Binding var watermark: WatermarkPreset
    @Binding var photoFrame: PhotoFramePreset
    @Binding var guidanceSettings: PhotoGuidanceSettings
    let currentStyleName: String
    let locationText: String?
    let requestLocation: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWatermarkPhotoItem: PhotosPickerItem?
    @State private var watermarkImageImportError: String?

    var body: some View {
        NavigationStack {
            Form {
                watermarkSection
                photoFrameSection
                guidanceSection
            }
            .navigationTitle("设置")
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

    private var watermarkSection: some View {
        Section {
            Toggle("开启水印", isOn: $watermark.enabled)

            if watermark.enabled {
                Picker("模式", selection: $watermark.mode) {
                    ForEach(WatermarkMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch watermark.mode {
                case .manual:
                    manualWatermarkControls
                case .image:
                    imageWatermarkControls
                }

                WatermarkPreviewView(
                    watermark: watermark,
                    styleName: currentStyleName,
                    locationText: locationText
                )
                .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            }
        } header: {
            Text("水印")
        } footer: {
            if !watermark.enabled {
                Text("开启后可手动配置文字信息，或上传 PNG 图片作为水印。")
            }
        }
    }

    @ViewBuilder
    private var manualWatermarkControls: some View {
        Group {
            TextField("文字", text: $watermark.text)
            Toggle("显示风格", isOn: $watermark.includeStyleName)
            Toggle("显示日期", isOn: $watermark.includeDate)
            Toggle("显示设备", isOn: $watermark.includeDevice)
            Toggle("显示位置", isOn: includeLocationBinding)

            if watermark.includeLocation {
                TextField("位置文字", text: $watermark.locationOverrideText)
                Text("留空使用当前定位：\(locationText ?? "等待定位")")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }

        Group {
            WatermarkTextColorPicker(selection: $watermark.textColor)

            SettingsOptionGrid(
                title: "样式",
                selection: $watermark.visualStyle,
                options: WatermarkVisualStyle.allCases,
                label: { $0.title }
            )

            Picker("效果", selection: $watermark.effect) {
                ForEach(WatermarkEffect.allCases, id: \.self) { effect in
                    Text(effect.title).tag(effect)
                }
            }

            SettingsOptionGrid(
                title: "展示位置",
                selection: $watermark.position,
                options: WatermarkPosition.allCases,
                label: { $0.title }
            )

            HStack {
                Text("透明度")
                Slider(value: opacityBinding, in: 0.2...1)
            }
        }
    }

    @ViewBuilder
    private var imageWatermarkControls: some View {
        PhotosPicker(
            selection: $selectedWatermarkPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Label(
                watermarkImage == nil ? "从相册选择水印" : "从相册更换水印",
                systemImage: "photo.badge.plus"
            )
        }
        .task(id: selectedWatermarkPhotoItem) {
            guard let selectedWatermarkPhotoItem else { return }
            await importWatermarkImage(from: selectedWatermarkPhotoItem)
        }

        if let watermarkImage {
            HStack(spacing: 12) {
                Image(uiImage: watermarkImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)
                    .padding(8)
                    .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("已选择水印图片")
                        .font(.subheadline)
                    Text("\(Int(watermarkImage.size.width)) x \(Int(watermarkImage.size.height))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button(role: .destructive) {
                watermark.imageData = nil
            } label: {
                Label("移除图片水印", systemImage: "trash")
            }
        } else {
            Text("请从相册选择图片。推荐使用带透明背景的 PNG，适合用作签名、Logo 或图形水印。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if let watermarkImageImportError {
            Text(watermarkImageImportError)
                .font(.footnote)
                .foregroundStyle(.red)
        }

        SettingsOptionGrid(
            title: "展示位置",
            selection: $watermark.position,
            options: WatermarkPosition.allCases,
            label: { $0.title }
        )

        HStack {
            Text("大小")
            Slider(value: imageScaleBinding, in: 0.08...0.6)
        }

        HStack {
            Text("透明度")
            Slider(value: opacityBinding, in: 0.2...1)
        }
    }

    private var photoFrameSection: some View {
        Section {
            Toggle("开启相框", isOn: $photoFrame.enabled)

            if photoFrame.enabled {
                Picker("样式", selection: $photoFrame.style) {
                    ForEach(PhotoFrameStyle.allCases, id: \.self) { style in
                        Text(style.title).tag(style)
                    }
                }

                HStack {
                    Text("强度")
                    Slider(value: frameOpacityBinding, in: 0.45...1)
                }

                PhotoFramePreviewView(preset: photoFrame)
                    .listRowInsets(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            }
        } header: {
            Text("相框")
        } footer: {
            if !photoFrame.enabled {
                Text("开启后可选择相框样式并调整强度。")
            }
        }
    }

    private var guidanceSection: some View {
        Section {
            Toggle("开启指导", isOn: $guidanceSettings.isEnabled)

            if guidanceSettings.isEnabled {
                Picker("提示强度", selection: $guidanceSettings.intensity) {
                    ForEach(PhotoGuidanceIntensity.allCases, id: \.self) { intensity in
                        Text(intensity.title).tag(intensity)
                    }
                }

                Toggle("构图建议", isOn: $guidanceSettings.compositionEnabled)
                Toggle("水平角度", isOn: $guidanceSettings.angleEnabled)
                Toggle("光线提醒", isOn: $guidanceSettings.lightEnabled)
                Toggle("清晰度提醒", isOn: $guidanceSettings.sharpnessEnabled)
                Toggle("风格建议", isOn: $guidanceSettings.styleEnabled)
            }
        } header: {
            Text("AI 拍照指导")
        } footer: {
            if !guidanceSettings.isEnabled {
                Text("开启后可配置提示强度和建议类型。")
            }
        }
    }

    private var opacityBinding: Binding<Double> {
        Binding(
            get: { Double(watermark.opacity) },
            set: { watermark.opacity = Float($0) }
        )
    }

    private var imageScaleBinding: Binding<Double> {
        Binding(
            get: { Double(watermark.imageScale) },
            set: { watermark.imageScale = Float($0) }
        )
    }

    private var frameOpacityBinding: Binding<Double> {
        Binding(
            get: { Double(photoFrame.opacity) },
            set: { photoFrame.opacity = Float($0) }
        )
    }

    private var watermarkImage: UIImage? {
        guard let imageData = watermark.imageData else {
            return nil
        }

        return UIImage(data: imageData)
    }

    private var includeLocationBinding: Binding<Bool> {
        Binding(
            get: { watermark.includeLocation },
            set: { newValue in
                watermark.includeLocation = newValue
                if newValue {
                    requestLocation()
                }
            }
        )
    }

    private func importWatermarkImage(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let pngData = normalizedWatermarkPNGData(from: image) else {
                watermarkImageImportError = "无法读取这张图片。"
                return
            }
            guard !Task.isCancelled else { return }

            watermark.mode = .image
            watermark.imageData = pngData
            watermarkImageImportError = nil
        } catch is CancellationError {
            return
        } catch {
            watermarkImageImportError = "图片导入失败，请重新选择。"
        }
    }

    private func normalizedWatermarkPNGData(from image: UIImage) -> Data? {
        let pixelWidth = CGFloat(image.cgImage?.width ?? Int(image.size.width * image.scale))
        let pixelHeight = CGFloat(image.cgImage?.height ?? Int(image.size.height * image.scale))
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        let maximumPixelLength: CGFloat = 1_024
        let resizeScale = min(1, maximumPixelLength / max(pixelWidth, pixelHeight))
        let targetSize = CGSize(
            width: max(1, (pixelWidth * resizeScale).rounded()),
            height: max(1, (pixelHeight * resizeScale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let normalizedImage = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return normalizedImage.pngData()
    }
}

private struct SettingsOptionGrid<Option: Hashable>: View {
    let title: String
    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> String

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(options, id: \.self) { option in
                    optionButton(option)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func optionButton(_ option: Option) -> some View {
        let isSelected = option == selection

        return Button {
            selection = option
        } label: {
            HStack(spacing: 8) {
                Text(label(option))
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 6)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.yellow.opacity(0.18) : Color.secondary.opacity(0.1))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.yellow.opacity(0.82) : Color.secondary.opacity(0.16), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct WatermarkPreviewView: View {
    let watermark: WatermarkPreset
    let styleName: String
    let locationText: String?

    var body: some View {
        ZStack(alignment: alignment) {
            LinearGradient(
                colors: [
                    Color(red: 0.52, green: 0.60, blue: 0.62),
                    Color(red: 0.22, green: 0.18, blue: 0.15),
                    Color(red: 0.72, green: 0.66, blue: 0.50)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                GridOverlayView()
                    .opacity(0.35)
            }

            if watermark.enabled {
                previewWatermark
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            }
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var previewWatermark: some View {
        switch watermark.mode {
        case .manual:
            if !previewText.isEmpty {
                Text(previewText)
                    .font(previewFont)
                    .foregroundStyle(foregroundColor)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, verticalPadding)
                    .background(backgroundShape)
                    .shadow(color: effectColor, radius: effectRadius, x: 0, y: effectYOffset)
            }
        case .image:
            if let watermarkImage {
                Image(uiImage: watermarkImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: max(42, 160 * CGFloat(watermark.imageScale)))
                    .opacity(Double(watermark.opacity))
                    .shadow(color: effectColor, radius: effectRadius, x: 0, y: effectYOffset)
            } else {
                Text("未选择 PNG")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.34), in: Capsule())
            }
        }
    }

    private var previewText: String {
        var parts = [String]()
        let text = watermark.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            parts.append(text)
        }
        if watermark.includeStyleName {
            parts.append(styleName)
        }
        if watermark.includeDevice {
            parts.append("iPhone")
        }
        if watermark.includeLocation {
            let locationOverrideText = watermark.locationOverrideText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !locationOverrideText.isEmpty {
                parts.append(locationOverrideText)
            } else {
                parts.append(locationText ?? "当前位置")
            }
        }
        if watermark.includeDate {
            parts.append("2026.07.05")
        }
        return parts.joined(separator: " · ")
    }

    private var watermarkImage: UIImage? {
        guard let imageData = watermark.imageData else {
            return nil
        }

        return UIImage(data: imageData)
    }

    private var alignment: Alignment {
        switch watermark.position {
        case .topLeft: return .topLeading
        case .topRight: return .topTrailing
        case .bottomLeft: return .bottomLeading
        case .bottomRight: return .bottomTrailing
        case .bottomCenter: return .bottom
        case .custom: return .center
        }
    }

    private var previewFont: Font {
        switch watermark.visualStyle {
        case .film:
            return .system(size: 13, weight: .medium, design: .monospaced)
        case .darkBadge, .lightBadge:
            return .system(size: 14, weight: .semibold)
        case .minimal:
            return .system(size: 14, weight: .medium)
        }
    }

    private var foregroundColor: Color {
        let alpha = Double(watermark.opacity)
        switch watermark.visualStyle {
        case .minimal, .darkBadge:
            return watermark.textColor.previewColor(fallback: .white, opacity: alpha)
        case .lightBadge:
            return watermark.textColor.previewColor(fallback: .black, opacity: alpha * 0.76)
        case .film:
            return watermark.textColor.previewColor(
                fallback: Color(red: 1.0, green: 0.88, blue: 0.36),
                opacity: alpha
            )
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        switch watermark.visualStyle {
        case .minimal:
            Color.clear
        case .darkBadge:
            Capsule().fill(.black.opacity(Double(watermark.opacity) * 0.46))
        case .lightBadge:
            Capsule().fill(.white.opacity(Double(watermark.opacity) * 0.72))
        case .film:
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(Double(watermark.opacity) * 0.58))
        }
    }

    private var horizontalPadding: CGFloat {
        watermark.visualStyle == .minimal ? 0 : 12
    }

    private var verticalPadding: CGFloat {
        watermark.visualStyle == .minimal ? 0 : 7
    }

    private var effectColor: Color {
        switch watermark.effect {
        case .none: return .clear
        case .shadow: return .black.opacity(Double(watermark.opacity) * 0.48)
        case .glow: return .white.opacity(Double(watermark.opacity) * 0.64)
        }
    }

    private var effectRadius: CGFloat {
        switch watermark.effect {
        case .none: return 0
        case .shadow: return 8
        case .glow: return 14
        }
    }

    private var effectYOffset: CGFloat {
        watermark.effect == .shadow ? 2 : 0
    }
}

private struct PhotoFramePreviewView: View {
    let preset: PhotoFramePreset

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.72, green: 0.84, blue: 0.90),
                    Color(red: 0.72, green: 0.42, blue: 0.22),
                    Color(red: 0.12, green: 0.13, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .padding(contentPadding)

            LiveFrameOverlayView(preset: preset)
        }
        .frame(height: 160)
        .background(frameBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var contentPadding: EdgeInsets {
        switch preset.style {
        case .cleanWhite, .cleanBlack:
            return EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        case .instant:
            return EdgeInsets(top: 12, leading: 12, bottom: 42, trailing: 12)
        case .film:
            return EdgeInsets(top: 10, leading: 28, bottom: 10, trailing: 28)
        }
    }

    private var frameBackground: Color {
        switch preset.style {
        case .cleanWhite, .instant:
            return Color.white.opacity(Double(preset.opacity))
        case .cleanBlack, .film:
            return Color.black.opacity(Double(preset.opacity))
        }
    }
}

private extension WatermarkMode {
    var title: String {
        switch self {
        case .manual: return "手动配置"
        case .image: return "PNG 图片"
        }
    }
}

private extension WatermarkPosition {
    var title: String {
        switch self {
        case .topLeft: return "左上"
        case .topRight: return "右上"
        case .bottomLeft: return "左下"
        case .bottomRight: return "右下"
        case .bottomCenter: return "底部居中"
        case .custom: return "自由拖动"
        }
    }
}

private extension PhotoFrameStyle {
    var title: String {
        switch self {
        case .cleanWhite: return "简约白边"
        case .cleanBlack: return "简约黑边"
        case .instant: return "拍立得"
        case .film: return "胶片边"
        }
    }
}

private extension WatermarkVisualStyle {
    var title: String {
        switch self {
        case .minimal: return "简约文字"
        case .darkBadge: return "深色标签"
        case .lightBadge: return "浅色标签"
        case .film: return "胶片"
        }
    }
}

private extension WatermarkTextColor {
    var title: String {
        switch self {
        case .automatic: return "自动"
        case .white: return "白色"
        case .black: return "黑色"
        case .yellow: return "黄色"
        case .orange: return "橙色"
        case .blue: return "蓝色"
        case .pink: return "粉色"
        }
    }

    var swatchColor: Color {
        switch self {
        case .automatic: return .clear
        case .white: return .white
        case .black: return .black
        case .yellow: return Color(red: 1.0, green: 0.86, blue: 0.12)
        case .orange: return Color(red: 1.0, green: 0.48, blue: 0.16)
        case .blue: return Color(red: 0.36, green: 0.64, blue: 1.0)
        case .pink: return Color(red: 1.0, green: 0.48, blue: 0.72)
        }
    }

    func previewColor(fallback: Color, opacity: Double) -> Color {
        switch self {
        case .automatic:
            return fallback.opacity(opacity)
        case .white:
            return Color.white.opacity(opacity)
        case .black:
            return Color.black.opacity(opacity)
        case .yellow:
            return Color(red: 1.0, green: 0.86, blue: 0.12).opacity(opacity)
        case .orange:
            return Color(red: 1.0, green: 0.48, blue: 0.16).opacity(opacity)
        case .blue:
            return Color(red: 0.36, green: 0.64, blue: 1.0).opacity(opacity)
        case .pink:
            return Color(red: 1.0, green: 0.48, blue: 0.72).opacity(opacity)
        }
    }
}

private extension WatermarkEffect {
    var title: String {
        switch self {
        case .none: return "无"
        case .shadow: return "阴影"
        case .glow: return "柔光"
        }
    }
}

private extension PhotoGuidanceIntensity {
    var title: String {
        switch self {
        case .quiet: return "安静"
        case .standard: return "标准"
        case .active: return "积极"
        }
    }
}

private struct WatermarkTextColorPicker: View {
    @Binding var selection: WatermarkTextColor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("文字颜色")

            HStack(spacing: 12) {
                ForEach(WatermarkTextColor.allCases, id: \.self) { color in
                    Button {
                        selection = color
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.secondary.opacity(0.12))
                                .frame(width: 34, height: 34)

                            if color == .automatic {
                                Text("A")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.primary)
                            } else {
                                Circle()
                                    .fill(color.swatchColor)
                                    .frame(width: 22, height: 22)
                                    .overlay {
                                        Circle()
                                            .stroke(.black.opacity(color == .white ? 0.18 : 0), lineWidth: 1)
                                    }
                            }

                            if selection == color {
                                Circle()
                                    .stroke(.yellow, lineWidth: 2)
                                    .frame(width: 34, height: 34)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(color.title)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct WatermarkToggleButton: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(systemName: "textformat")
                    .font(.system(size: 20, weight: .semibold))

                if !isOn {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.white.opacity(0.88))
                        .frame(width: 26, height: 2)
                        .rotationEffect(.degrees(-34))
                }

                Circle()
                    .fill(isOn ? .yellow : .white.opacity(0.58))
                    .frame(width: 5, height: 5)
                    .offset(x: 13, y: -12)
            }
            .foregroundStyle(isOn ? .yellow : .white.opacity(0.78))
            .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "关闭水印" : "开启水印")
    }
}

private struct GridOverlayView: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height
                path.move(to: CGPoint(x: width / 3, y: 0))
                path.addLine(to: CGPoint(x: width / 3, y: height))
                path.move(to: CGPoint(x: width * 2 / 3, y: 0))
                path.addLine(to: CGPoint(x: width * 2 / 3, y: height))
                path.move(to: CGPoint(x: 0, y: height / 3))
                path.addLine(to: CGPoint(x: width, y: height / 3))
                path.move(to: CGPoint(x: 0, y: height * 2 / 3))
                path.addLine(to: CGPoint(x: width, y: height * 2 / 3))
            }
            .stroke(.white.opacity(0.42), lineWidth: 0.8)
        }
        .allowsHitTesting(false)
    }
}

private struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    let onSelect: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, dismiss: dismiss)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onSelect: (UIImage) -> Void
        private let dismiss: DismissAction

        init(onSelect: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onSelect = onSelect
            self.dismiss = dismiss
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                dismiss()
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [onSelect, dismiss] object, _ in
                if let image = object as? UIImage {
                    Task { @MainActor in
                        onSelect(image)
                        dismiss()
                    }
                } else {
                    Task { @MainActor in
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct LensDialView: View {
    let zoom: CGFloat
    let setZoom: (CGFloat) -> Void
    let finish: () -> Void

    @State private var dragStartZoom: CGFloat?

    private let fixedMarks: [(zoom: CGFloat, text: String, mm: String)] = [
        (0.5, "0.5", "13MM"),
        (1, "1", "24MM"),
        (2, "2", "48MM"),
        (5, "5", "120MM"),
        (10, "10", "240MM")
    ]
    private let tickCount = 101

    var body: some View {
        GeometryReader { proxy in
            let layout = LensDialLayout(size: proxy.size)

            ZStack(alignment: .bottom) {
                Circle()
                    .fill(.black.opacity(0.36))
                    .frame(width: layout.radius * 2, height: layout.radius * 2)
                    .position(x: layout.centerX, y: layout.centerY)

                tickArc(layout: layout)

                fixedLabels(layout: layout)

                VStack(spacing: 0) {
                    Text(zoomText)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.yellow)
                    Text(focalLengthText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.yellow.opacity(0.88))
                }
                .position(x: layout.centerX, y: layout.readoutY)

                Image(systemName: "triangle.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.yellow)
                    .rotationEffect(.degrees(180))
                    .position(x: layout.centerX, y: layout.pointerY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let startZoom = dragStartZoom ?? zoom
                        if dragStartZoom == nil {
                            dragStartZoom = startZoom
                        }

                        let startProgress = LensZoomScale.progress(for: startZoom)
                        let progressDelta = value.translation.width / max(1, proxy.size.width * 0.88)
                        setZoom(LensZoomScale.roundedZoom(fromProgress: startProgress + progressDelta))
                    }
                    .onEnded { _ in
                        dragStartZoom = nil
                        finish()
                    }
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func tickArc(layout: LensDialLayout) -> some View {
        ZStack {
            ForEach(0..<tickCount, id: \.self) { index in
                let tickZoom = LensZoomScale.zoom(fromProgress: CGFloat(index) / CGFloat(tickCount - 1))
                let angle = dialAngle(for: tickZoom)
                let isMajor = index % 10 == 0 || fixedMarks.contains { abs($0.zoom - tickZoom) < 0.035 }

                Rectangle()
                    .fill(.white.opacity(isMajor ? 0.72 : 0.34))
                    .frame(width: 1, height: isMajor ? 28 : 16)
                    .rotationEffect(.degrees(angle))
                    .position(layout.tickPoint(for: angle))
                    .opacity(tickOpacity(for: angle))
            }
        }
    }

    private func fixedLabels(layout: LensDialLayout) -> some View {
        ZStack {
            ForEach(fixedMarks.indices, id: \.self) { index in
                let mark = fixedMarks[index]
                let angle = dialAngle(for: mark.zoom)

                VStack(spacing: 1) {
                    Text(mark.text)
                        .font(.system(size: 20, weight: .medium))
                    Text(mark.mm)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.74))
                .rotationEffect(.degrees(angle * 0.42))
                .position(layout.labelPoint(for: angle))
                .opacity(labelOpacity(for: angle))
            }
        }
    }

    private var zoomText: String {
        if abs(zoom.rounded() - zoom) < 0.05 {
            return "\(Int(zoom.rounded()))x"
        }
        return String(format: "%.1fx", Double(zoom))
    }

    private var focalLengthText: String {
        "\(Int(LensZoomScale.focalLength(for: zoom).rounded()))MM"
    }

    private func dialAngle(for value: CGFloat) -> Double {
        let relativeProgress = LensZoomScale.progress(for: value) - LensZoomScale.progress(for: zoom)
        return Double(relativeProgress * 124)
    }

    private func tickOpacity(for angle: Double) -> Double {
        let distance = abs(angle)
        guard distance <= 78 else { return 0 }
        if distance <= 54 { return 1 }
        return max(0, 1 - (distance - 54) / 24)
    }

    private func labelOpacity(for angle: Double) -> Double {
        let distance = abs(angle)
        guard distance > 9, distance <= 76 else { return 0 }
        if distance <= 56 { return 1 }
        return max(0, 1 - (distance - 56) / 20)
    }
}

private struct LensDialLayout {
    let size: CGSize

    var centerX: CGFloat {
        size.width / 2
    }

    var radius: CGFloat {
        max(220, size.width * 0.64)
    }

    var centerY: CGFloat {
        radius + 50
    }

    var pointerY: CGFloat {
        36
    }

    var readoutY: CGFloat {
        82
    }

    func tickPoint(for angle: Double) -> CGPoint {
        point(for: angle, radius: radius)
    }

    func labelPoint(for angle: Double) -> CGPoint {
        point(for: angle, radius: radius - 42)
    }

    private func point(for angle: Double, radius: CGFloat) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(
            x: centerX + sin(radians) * radius,
            y: centerY - cos(radians) * radius
        )
    }
}

private enum LensZoomScale {
    static let minZoom: CGFloat = 0.5
    static let maxZoom: CGFloat = 10

    static func progress(for zoom: CGFloat) -> CGFloat {
        let clampedZoom = min(maxZoom, max(minZoom, zoom))
        return log(clampedZoom / minZoom) / log(maxZoom / minZoom)
    }

    static func zoom(fromProgress progress: CGFloat) -> CGFloat {
        let clampedProgress = min(1, max(0, progress))
        return minZoom * pow(maxZoom / minZoom, clampedProgress)
    }

    static func roundedZoom(fromProgress progress: CGFloat) -> CGFloat {
        roundedZoom(zoom(fromProgress: progress))
    }

    static func roundedZoom(_ zoom: CGFloat) -> CGFloat {
        (min(maxZoom, max(minZoom, zoom)) * 10).rounded() / 10
    }

    static func focalLength(for zoom: CGFloat) -> CGFloat {
        switch zoom {
        case ...1:
            return 13 + (zoom - 0.5) / 0.5 * 11
        case ...2:
            return 24 + (zoom - 1) * 24
        case ...5:
            return 48 + (zoom - 2) / 3 * 72
        default:
            return 120 + (zoom - 5) / 5 * 120
        }
    }
}
