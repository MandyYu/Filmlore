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
    @State private var pinchStartZoom: CGFloat?

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
                            presets: viewModel.visibleStylePresets,
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
                previewStore: viewModel.rawPreviewStore,
                save: viewModel.saveCustomStyle
            )
            .onAppear {
                viewModel.setStyleEditorPreviewActive(true)
            }
            .onDisappear {
                viewModel.setStyleEditorPreviewActive(false)
            }
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
                previewStore: viewModel.previewStore,
                rawPreviewStore: viewModel.rawPreviewStore,
                stylePreviewStore: viewModel.stylePreviewStore,
                stylePresets: viewModel.selection.presets,
                disabledStyleIDs: viewModel.disabledStyleIDs,
                selectedStyleID: viewModel.selection.selectedPreset.id,
                createStyle: viewModel.createCustomStyle,
                updateStyle: viewModel.updateCustomStyle,
                setStyleEnabled: viewModel.setStyleEnabled,
                setStyleEditorPreviewActive: viewModel.setStyleEditorPreviewActive,
                currentStyleName: viewModel.selection.selectedPreset.name,
                locationText: viewModel.locationText,
                requestLocation: viewModel.requestWatermarkLocation
            )
            .presentationDetents([.large])
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
                .simultaneousGesture(pinchZoomGesture)

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

    private var pinchZoomGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.005)
            .onChanged { value in
                let startZoom = pinchStartZoom ?? viewModel.selectedLens
                if pinchStartZoom == nil {
                    pinchStartZoom = startZoom
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
                        isLensDialVisible = true
                    }
                }

                let zoom = LensZoomScale.clampedZoom(startZoom * value.magnification)
                viewModel.setZoomInteractively(zoom)
            }
            .onEnded { value in
                let startZoom = pinchStartZoom ?? viewModel.selectedLens
                let zoom = LensZoomScale.roundedZoom(startZoom * value.magnification)
                pinchStartZoom = nil
                viewModel.setZoomInteractively(zoom)
                finishLensDial()
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
            RoundedRectangle(cornerRadius: frameCornerRadius, style: .continuous)
                .strokeBorder(frameColor.opacity(Double(preset.opacity)), lineWidth: frameLineWidth)
                .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowYOffset)
        case .instant:
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: frameCornerRadius, style: .continuous)
                    .strokeBorder(frameColor.opacity(Double(preset.opacity)), lineWidth: frameLineWidth)
                    .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowYOffset)

                Rectangle()
                    .fill(frameColor.opacity(Double(preset.opacity)))
                    .frame(height: max(frameLineWidth * 3.1, size.height * 0.12))
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
                RoundedRectangle(cornerRadius: frameCornerRadius, style: .continuous)
                    .strokeBorder(frameColor.opacity(Double(preset.opacity) * 0.92), lineWidth: frameLineWidth)
                    .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowYOffset)
            }
        case .minimal:
            RoundedRectangle(cornerRadius: frameCornerRadius, style: .continuous)
                .strokeBorder(
                    frameColor.opacity(Double(preset.opacity)),
                    lineWidth: max(3, frameLineWidth * 0.55)
                )
                .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowYOffset)
        }
    }

    private var frameColor: Color {
        preset.backgroundColor.color
    }

    private var frameLineWidth: CGFloat {
        CGFloat(preset.borderWidth)
    }

    private var frameCornerRadius: CGFloat {
        CGFloat(preset.cornerRadius)
    }

    private var shadowColor: Color {
        preset.shadowEnabled ? .black.opacity(0.34) : .clear
    }

    private var shadowRadius: CGFloat {
        preset.shadowEnabled ? 8 : 0
    }

    private var shadowYOffset: CGFloat {
        preset.shadowEnabled ? 3 : 0
    }

    private var filmRail: some View {
        VStack(spacing: 10) {
            ForEach(0..<8, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(.white.opacity(Double(preset.opacity) * 0.24))
                    .frame(width: 8, height: 18)
            }
        }
        .frame(width: max(24, frameLineWidth * 1.65))
        .background(frameColor.opacity(Double(preset.opacity) * 0.92))
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

private enum CameraSettingsRoute: Hashable {
    case styles
    case watermark
    case photoFrame
    case guidance
}

private struct StyleEditorRequest: Identifiable {
    let id = UUID()
    let preset: StylePreset
    let createsNewStyle: Bool
}

private struct CameraSettingsView: View {
    @Binding var watermark: WatermarkPreset
    @Binding var photoFrame: PhotoFramePreset
    @Binding var guidanceSettings: PhotoGuidanceSettings
    let previewStore: CameraPreviewStore
    let rawPreviewStore: CameraPreviewStore
    let stylePreviewStore: StylePreviewStore
    let stylePresets: [StylePreset]
    let disabledStyleIDs: Set<StylePreset.ID>
    let selectedStyleID: StylePreset.ID
    let createStyle: (String, StyleParams) -> StylePreset
    let updateStyle: (StylePreset.ID, String, StyleParams) -> StylePreset?
    let setStyleEnabled: (StylePreset.ID, Bool) -> Bool
    let setStyleEditorPreviewActive: (Bool) -> Void
    let currentStyleName: String
    let locationText: String?
    let requestLocation: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var navigationPath = [CameraSettingsRoute]()
    @State private var selectedWatermarkPhotoItem: PhotosPickerItem?
    @State private var watermarkImageImportError: String?
    @State private var managedStylePresets = [StylePreset]()
    @State private var managedDisabledStyleIDs = Set<StylePreset.ID>()
    @State private var managedSelectedStyleID: StylePreset.ID?
    @State private var styleEditorRequest: StyleEditorRequest?
    @State private var staticStyleThumbnails = [StylePreset.ID: UIImage]()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            settingsOverview
                .navigationDestination(for: CameraSettingsRoute.self) { route in
                    settingsDestination(for: route)
                }
        }
        .onAppear {
            guard managedStylePresets.isEmpty else { return }
            managedStylePresets = stylePresets
            managedDisabledStyleIDs = disabledStyleIDs
            managedSelectedStyleID = selectedStyleID
        }
        .sheet(item: $styleEditorRequest) { request in
            StyleEditorView(
                preset: request.preset,
                previewStore: rawPreviewStore,
                isCreatingNew: request.createsNewStyle,
                saveChanges: request.preset.isBuiltIn ? nil : saveStyleChanges,
                saveAsNew: saveStyleAsNew
            )
            .presentationDetents([.large])
            .onAppear {
                setStyleEditorPreviewActive(true)
            }
            .onDisappear {
                setStyleEditorPreviewActive(false)
            }
        }
    }

    private var settingsOverview: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                SettingsFeatureLinkCard(
                    title: "风格配置",
                    summary: "预设管理 / 参数调整 / 自定义风格",
                    iconName: "camera.filters",
                    tint: Color(red: 0.12, green: 0.58, blue: 0.62),
                    badge: "PRO",
                    open: { navigationPath.append(.styles) }
                )

                SettingsFeatureCard(
                    title: "水印",
                    summary: "时间 / 位置 / 风格 / 自定义签名",
                    iconName: "signature",
                    tint: Color(red: 0.20, green: 0.43, blue: 0.96),
                    isEnabled: $watermark.enabled,
                    open: { navigationPath.append(.watermark) }
                )

                SettingsFeatureCard(
                    title: "相框",
                    summary: "白边 / 黑边 / 拍立得 / 胶片",
                    iconName: "photo.on.rectangle.angled",
                    tint: Color(red: 0.94, green: 0.55, blue: 0.16),
                    isEnabled: $photoFrame.enabled,
                    open: { navigationPath.append(.photoFrame) }
                )

                SettingsFeatureCard(
                    title: "AI 指导",
                    summary: "构图 / 光线 / 水平 / 清晰度提醒",
                    iconName: "viewfinder",
                    tint: Color(red: 0.18, green: 0.66, blue: 0.42),
                    isEnabled: $guidanceSettings.isEnabled,
                    open: { navigationPath.append(.guidance) }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
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

    @ViewBuilder
    private func settingsDestination(for route: CameraSettingsRoute) -> some View {
        switch route {
        case .styles:
            styleSettingsPage
        case .watermark:
            watermarkSettingsPage
        case .photoFrame:
            photoFrameSettingsPage
        case .guidance:
            guidanceSettingsPage
        }
    }

    private var styleSettingsPage: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("拍摄风格")
                            .font(.headline)
                        Text("勾选的风格会显示在拍摄页滤镜列表中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("PRO")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(Color.blue, in: Capsule())
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(displayedStylePresets) { preset in
                        StyleManagementCard(
                            preset: preset,
                            previewImage: styleCoverImage(for: preset),
                            isEnabled: !managedDisabledStyleIDs.contains(preset.id),
                            isCurrent: preset.id == effectiveSelectedStyleID,
                            edit: {
                                styleEditorRequest = StyleEditorRequest(
                                    preset: preset,
                                    createsNewStyle: false
                                )
                            },
                            toggleEnabled: {
                                toggleManagedStyle(preset)
                            }
                        )
                    }

                    AddCustomStyleCard {
                        beginCreatingStyle()
                    }
                }

                Label("至少需要保留一个可用风格。自定义风格会自动勾选。", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("风格配置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            captureMissingStaticThumbnails(from: stylePreviewStore.images)
        }
        .onReceive(stylePreviewStore.$images) { images in
            captureMissingStaticThumbnails(from: images)
        }
    }

    private var displayedStylePresets: [StylePreset] {
        managedStylePresets.isEmpty ? stylePresets : managedStylePresets
    }

    private var effectiveSelectedStyleID: StylePreset.ID {
        managedSelectedStyleID ?? selectedStyleID
    }

    private func toggleManagedStyle(_ preset: StylePreset) {
        let shouldEnable = managedDisabledStyleIDs.contains(preset.id)
        guard setStyleEnabled(preset.id, shouldEnable) else { return }

        if shouldEnable {
            managedDisabledStyleIDs.remove(preset.id)
            return
        }

        managedDisabledStyleIDs.insert(preset.id)
        if effectiveSelectedStyleID == preset.id,
           let replacement = displayedStylePresets.first(where: {
               !managedDisabledStyleIDs.contains($0.id)
           }) {
            managedSelectedStyleID = replacement.id
        }
    }

    private func beginCreatingStyle() {
        let basePreset = displayedStylePresets.first(where: { $0.id == effectiveSelectedStyleID })
            ?? BuiltInPresets.original
        styleEditorRequest = StyleEditorRequest(
            preset: basePreset,
            createsNewStyle: true
        )
    }

    private func saveStyleAsNew(_ name: String, _ params: StyleParams) {
        let preset = createStyle(name, params)
        managedStylePresets.append(preset)
        managedDisabledStyleIDs.remove(preset.id)
        managedSelectedStyleID = preset.id
    }

    private func saveStyleChanges(
        _ id: StylePreset.ID,
        _ name: String,
        _ params: StyleParams
    ) {
        guard let preset = updateStyle(id, name, params),
              let index = managedStylePresets.firstIndex(where: { $0.id == id }) else {
            return
        }
        managedStylePresets[index] = preset
        staticStyleThumbnails[preset.id] = nil
    }

    private func captureMissingStaticThumbnails(
        from images: [StylePreset.ID: UIImage]
    ) {
        for preset in displayedStylePresets where
            fixedStyleCover(for: preset) == nil
            && staticStyleThumbnails[preset.id] == nil {
            if let image = images[preset.id] {
                staticStyleThumbnails[preset.id] = image
            }
        }
    }

    private func styleCoverImage(for preset: StylePreset) -> UIImage? {
        fixedStyleCover(for: preset) ?? staticStyleThumbnails[preset.id]
    }

    private func fixedStyleCover(for preset: StylePreset) -> UIImage? {
        switch preset.id {
        case BuiltInPresets.foodINS.id:
            return UIImage(named: "food-ins-cover")
        case BuiltInPresets.cityTexture.id:
            return UIImage(named: "city-texture-cover")
        default:
            return nil
        }
    }

    private var watermarkSettingsPage: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                SettingsToggleCard(title: "启用水印", isOn: $watermark.enabled)

                if watermark.enabled {
                    WatermarkModeSelector(selection: $watermark.mode)

                    switch watermark.mode {
                    case .manual:
                        manualWatermarkControls
                    case .image:
                        imageWatermarkControls
                    }

                    SettingsSectionTitle("展示位置")
                    SettingsDetailCard {
                        WatermarkPositionPicker(selection: $watermark.position)

                        Divider()

                        SettingsSliderRow(
                            title: "背景透明度",
                            value: opacityBinding,
                            range: 0.2...1,
                            valueText: "\(Int((opacityBinding.wrappedValue * 100).rounded()))%"
                        )

                        if watermark.mode == .image {
                            Divider()

                            SettingsSliderRow(
                                title: "图片大小",
                                value: imageScaleBinding,
                                range: 0.08...0.6,
                                valueText: "\(Int((imageScaleBinding.wrappedValue * 100).rounded()))%"
                            )
                        }
                    }

                    SettingsSectionTitle("预览效果")
                    WatermarkPreviewView(
                        previewStore: previewStore,
                        watermark: watermark,
                        styleName: currentStyleName,
                        locationText: locationText
                    )
                } else {
                    SettingsDisabledHint(text: "开启后可手动组合文字信息，或从相册选择 PNG 图片作为水印。")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("水印")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var manualWatermarkControls: some View {
        SettingsDetailCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("自定义签名")
                    .font(.subheadline.weight(.semibold))

                TextField("例如：我的旅拍", text: $watermark.text)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            SettingsCompactToggle(title: "显示风格", isOn: $watermark.includeStyleName)
            SettingsCompactToggle(title: "显示日期", isOn: $watermark.includeDate)
            SettingsCompactToggle(title: "显示设备", isOn: $watermark.includeDevice)
            SettingsCompactToggle(title: "显示位置", isOn: includeLocationBinding)

            if watermark.includeLocation {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("位置文字", text: $watermark.locationOverrideText)
                        .textFieldStyle(.roundedBorder)
                    Text("留空使用当前定位：\(locationText ?? "等待定位")")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }

        SettingsDetailCard {
            WatermarkTextColorPicker(selection: $watermark.textColor)

            Divider()

            SettingsOptionGrid(
                title: "字体样式",
                selection: $watermark.visualStyle,
                options: WatermarkVisualStyle.allCases,
                label: { $0.title }
            )

            Divider()

            HStack {
                Text("阴影效果")
                Spacer()
                Picker("阴影效果", selection: $watermark.effect) {
                    ForEach(WatermarkEffect.allCases, id: \.self) { effect in
                        Text(effect.title).tag(effect)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
    }

    @ViewBuilder
    private var imageWatermarkControls: some View {
        SettingsDetailCard {
            HStack(alignment: .top, spacing: 14) {
                PhotosPicker(
                    selection: $selectedWatermarkPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    ZStack {
                        if let watermarkImage {
                            Image(uiImage: watermarkImage)
                                .resizable()
                                .scaledToFit()
                                .padding(16)
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 30, weight: .medium))
                                Text("尚未上传水印")
                                    .font(.caption)
                                Text("从相册选择")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .frame(height: 32)
                                    .background(Color.blue, in: Capsule())
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 132, height: 150)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.secondary.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [5]))
                    }
                }
                .buttonStyle(.plain)
                .task(id: selectedWatermarkPhotoItem) {
                    guard let selectedWatermarkPhotoItem else { return }
                    await importWatermarkImage(from: selectedWatermarkPhotoItem)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("图片水印")
                        .font(.subheadline.weight(.semibold))
                    Text("推荐使用透明背景 PNG，适合签名、Logo 或图形标记。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let watermarkImage {
                        Text("\(Int(watermarkImage.size.width)) x \(Int(watermarkImage.size.height))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Button(role: .destructive) {
                            watermark.imageData = nil
                            selectedWatermarkPhotoItem = nil
                        } label: {
                            Label("移除图片", systemImage: "trash")
                                .font(.caption.weight(.semibold))
                        }
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            }

            if let watermarkImageImportError {
                Text(watermarkImageImportError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var photoFrameSettingsPage: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                SettingsToggleCard(title: "启用相框", isOn: $photoFrame.enabled)

                if photoFrame.enabled {
                    SettingsSectionTitle("相框样式")
                PhotoFrameStylePicker(selection: frameStyleBinding)

                    SettingsDetailCard {
                        SettingsSliderRow(
                            title: "边框粗细",
                            systemImage: "rectangle.inset.filled",
                            value: frameBorderWidthBinding,
                            range: 4...40,
                            valueText: "\(Int(photoFrame.borderWidth.rounded()))"
                        )

                        Divider()

                        SettingsSliderRow(
                            title: "圆角半径",
                            systemImage: "circle",
                            value: frameCornerRadiusBinding,
                            range: 0...30,
                            valueText: "\(Int(photoFrame.cornerRadius.rounded()))"
                        )

                        Divider()

                        SettingsCompactToggle(
                            title: "阴影效果",
                            systemImage: "hexagon",
                            isOn: $photoFrame.shadowEnabled
                        )

                        Divider()

                        PhotoFrameBackgroundColorPicker(selection: $photoFrame.backgroundColor)
                    }

                    SettingsSectionTitle("预览效果")
                    PhotoFramePreviewView(previewStore: previewStore, preset: photoFrame)
                } else {
                    SettingsDisabledHint(text: "开启后可选择白边、黑边、拍立得、胶片或极简相框。")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("相框")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var guidanceSettingsPage: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                SettingsToggleCard(title: "启用 AI 指导", isOn: $guidanceSettings.isEnabled)

                if guidanceSettings.isEnabled {
                    SettingsDetailCard {
                        HStack {
                            Text("提示强度")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(guidanceSettings.intensity.title)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: guidanceIntensityBinding, in: 0...2, step: 1)

                        HStack {
                            Text("低")
                            Spacer()
                            Text("中")
                            Spacer()
                            Text("高")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    SettingsSectionTitle("智能提示项")
                    SettingsDetailCard(spacing: 0) {
                        GuidanceToggleRow(
                            title: "构图建议",
                            summary: "智能识别主体与构图，推荐更佳画面",
                            systemImage: "viewfinder",
                            tint: .indigo,
                            isOn: $guidanceSettings.compositionEnabled
                        )
                        Divider().padding(.leading, 52)
                        GuidanceToggleRow(
                            title: "水平角度",
                            summary: "检测地平线，提示画面水平",
                            systemImage: "level",
                            tint: .gray,
                            isOn: $guidanceSettings.angleEnabled
                        )
                        Divider().padding(.leading, 52)
                        GuidanceToggleRow(
                            title: "光线提醒",
                            summary: "识别光线条件，提供曝光建议",
                            systemImage: "sun.max.fill",
                            tint: .orange,
                            isOn: $guidanceSettings.lightEnabled
                        )
                        Divider().padding(.leading, 52)
                        GuidanceToggleRow(
                            title: "清晰度提醒",
                            summary: "识别模糊风险，建议保持稳定",
                            systemImage: "camera.metering.center.weighted",
                            tint: .cyan,
                            isOn: $guidanceSettings.sharpnessEnabled
                        )
                        Divider().padding(.leading, 52)
                        GuidanceToggleRow(
                            title: "风格提醒",
                            summary: "识别场景风格，推荐滤镜与色调",
                            systemImage: "paintpalette.fill",
                            tint: .pink,
                            isOn: $guidanceSettings.styleEnabled
                        )
                    }

                    SettingsSectionTitle("预览效果")
                    PhotoGuidancePreviewView(
                        previewStore: previewStore,
                        settings: guidanceSettings
                    )
                } else {
                    SettingsDisabledHint(text: "开启后可选择构图、水平、光线、清晰度和风格提示。")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("AI 拍照指导")
        .navigationBarTitleDisplayMode(.inline)
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

    private var guidanceIntensityBinding: Binding<Double> {
        Binding(
            get: {
                switch guidanceSettings.intensity {
                case .quiet: return 0
                case .standard: return 1
                case .active: return 2
                }
            },
            set: { value in
                switch Int(value.rounded()) {
                case 0: guidanceSettings.intensity = .quiet
                case 2: guidanceSettings.intensity = .active
                default: guidanceSettings.intensity = .standard
                }
            }
        )
    }

    private var frameStyleBinding: Binding<PhotoFrameStyle> {
        Binding(
            get: { photoFrame.style },
            set: { newStyle in
                var updated = photoFrame
                updated.style = newStyle
                switch newStyle {
                case .cleanWhite:
                    updated.backgroundColor = .white
                    updated.borderWidth = 24
                    updated.cornerRadius = 12
                    updated.shadowEnabled = true
                case .cleanBlack:
                    updated.backgroundColor = .black
                    updated.borderWidth = 24
                    updated.cornerRadius = 12
                    updated.shadowEnabled = true
                case .instant:
                    updated.backgroundColor = .white
                    updated.borderWidth = 18
                    updated.cornerRadius = 6
                    updated.shadowEnabled = true
                case .film:
                    updated.backgroundColor = .black
                    updated.borderWidth = 16
                    updated.cornerRadius = 4
                    updated.shadowEnabled = false
                case .minimal:
                    updated.backgroundColor = .white
                    updated.borderWidth = 8
                    updated.cornerRadius = 16
                    updated.shadowEnabled = false
                }
                photoFrame = updated
            }
        )
    }

    private var frameBorderWidthBinding: Binding<Double> {
        Binding(
            get: { Double(photoFrame.borderWidth) },
            set: { photoFrame.borderWidth = Float($0) }
        )
    }

    private var frameCornerRadiusBinding: Binding<Double> {
        Binding(
            get: { Double(photoFrame.cornerRadius) },
            set: { photoFrame.cornerRadius = Float($0) }
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

private struct SettingsFeatureCard: View {
    let title: String
    let summary: String
    let iconName: String
    let tint: Color
    @Binding var isEnabled: Bool
    let open: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 14) {
                    Image(systemName: iconName)
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 54, height: 54)
                        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        Text(isEnabled ? "已启用" : "未启用")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(isEnabled ? Color.green : Color.secondary)
                    }

                    Spacer(minLength: 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .accessibilityLabel("\(title)开关")

            Button(action: open) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("进入\(title)设置")
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.13), lineWidth: 1)
        }
    }
}

private struct SettingsFeatureLinkCard: View {
    let title: String
    let summary: String
    let iconName: String
    let tint: Color
    let badge: String?
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                Image(systemName: iconName)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 54, height: 54)
                    .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .frame(height: 19)
                                .background(Color.blue, in: Capsule())
                        }
                    }

                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 44)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.13), lineWidth: 1)
        }
    }
}

private struct StyleManagementCard: View {
    let preset: StylePreset
    let previewImage: UIImage?
    let isEnabled: Bool
    let isCurrent: Bool
    let edit: () -> Void
    let toggleEnabled: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: edit) {
                VStack(alignment: .leading, spacing: 0) {
                    preview
                        .frame(maxWidth: .infinity)
                        .frame(height: 112)
                        .clipped()

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(preset.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            if isCurrent {
                                Text("当前")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.blue)
                            }
                        }

                        Text(preset.isBuiltIn ? "内置风格" : "我的风格 · PRO")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                }
                .frame(maxWidth: .infinity, minHeight: 166, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: toggleEnabled) {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 23, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(isEnabled ? Color.blue : Color.secondary, Color.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isEnabled ? "从拍摄滤镜中隐藏\(preset.name)" : "在拍摄滤镜中显示\(preset.name)")
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isCurrent ? Color.blue : Color.secondary.opacity(0.13), lineWidth: isCurrent ? 2 : 1)
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let previewImage {
            Image(uiImage: previewImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.27, blue: 0.31),
                        Color(red: 0.58, green: 0.64, blue: 0.66)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                ProgressView()
                    .tint(.white)
            }
        }
    }
}

private struct AddCustomStyleCard: View {
    let add: () -> Void

    var body: some View {
        Button(action: add) {
            VStack(spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color.blue)
                        .frame(width: 58, height: 58)
                        .background(Color.blue.opacity(0.1), in: Circle())

                    Text("PRO")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(height: 17)
                        .background(Color.blue, in: Capsule())
                        .offset(x: 12, y: -5)
                }

                Text("自定义风格")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("新建并保存参数")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 166)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.blue.opacity(0.42), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
        }
    }
}

private struct SettingsToggleCard: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.headline)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        }
    }
}

private struct SettingsDetailCard<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        }
    }
}

private struct SettingsSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 2)
            .padding(.bottom, -6)
    }
}

private struct SettingsDisabledHint: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct WatermarkModeSelector: View {
    @Binding var selection: WatermarkMode

    var body: some View {
        HStack(spacing: 4) {
            modeButton(.image, title: "图片水印", systemImage: "photo")
            modeButton(.manual, title: "手动配置", systemImage: "pencil")
        }
        .padding(4)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func modeButton(_ mode: WatermarkMode, title: String, systemImage: String) -> some View {
        let isSelected = selection == mode

        return Button {
            selection = mode
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.blue : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(
                    isSelected ? Color.blue.opacity(0.1) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SettingsCompactToggle: View {
    let title: String
    let systemImage: String?
    @Binding var isOn: Bool

    init(title: String, systemImage: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.systemImage = systemImage
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 9) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                }
                Text(title)
                    .font(.subheadline)
            }
        }
        .frame(minHeight: 34)
    }
}

private struct SettingsSliderRow: View {
    let title: String
    let systemImage: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueText: String

    init(
        title: String,
        systemImage: String? = nil,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        valueText: String
    ) {
        self.title = title
        self.systemImage = systemImage
        _value = value
        self.range = range
        self.valueText = valueText
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .frame(width: systemImage == nil ? 86 : 104, alignment: .leading)

            Button {
                value = max(range.lowerBound, value - adjustmentStep)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 24, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("减小\(title)")

            Slider(value: $value, in: range)

            Button {
                value = min(range.upperBound, value + adjustmentStep)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 24, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("增大\(title)")

            Text(valueText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .trailing)
        }
    }

    private var adjustmentStep: Double {
        (range.upperBound - range.lowerBound) / 20
    }
}

private struct WatermarkPositionPicker: View {
    @Binding var selection: WatermarkPosition

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(WatermarkPosition.allCases, id: \.self) { position in
                let isSelected = selection == position

                Button {
                    selection = position
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: position.settingsIconName)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 42, height: 38)
                            .background(
                                isSelected ? Color.blue.opacity(0.1) : Color(uiColor: .tertiarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.15), lineWidth: isSelected ? 1.5 : 1)
                            }

                        Text(position.title)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(isSelected ? Color.blue : Color.secondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

private struct GuidanceToggleRow: View {
    let title: String
    let summary: String
    let systemImage: String
    let tint: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 9)
    }
}

private struct PhotoFrameStylePicker: View {
    @Binding var selection: PhotoFrameStyle

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PhotoFrameStyle.allCases, id: \.self) { style in
                    let isSelected = style == selection

                    Button {
                        selection = style
                    } label: {
                        VStack(spacing: 7) {
                            PhotoFrameStyleThumbnail(style: style)
                                .frame(width: 64, height: 82)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(
                                            isSelected ? Color.blue : Color.secondary.opacity(0.18),
                                            lineWidth: isSelected ? 2 : 1
                                        )
                                }

                            Text(style.shortTitle)
                                .font(.caption)
                                .fontWeight(isSelected ? .semibold : .regular)
                                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                                .frame(width: 64)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("选择\(style.title)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

private struct PhotoFrameStyleThumbnail: View {
    let style: PhotoFrameStyle

    var body: some View {
        ZStack {
            Color(uiColor: .tertiarySystemGroupedBackground)

            frameColor
                .frame(width: frameWidth, height: frameHeight)
                .clipShape(RoundedRectangle(cornerRadius: style == .minimal ? 8 : 4, style: .continuous))
                .shadow(color: .black.opacity(style == .film ? 0 : 0.16), radius: 3, x: 0, y: 2)

            LinearGradient(
                colors: [Color(red: 0.72, green: 0.86, blue: 0.97), Color(red: 0.24, green: 0.67, blue: 0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: imageWidth, height: imageHeight)
            .clipShape(RoundedRectangle(cornerRadius: style == .minimal ? 5 : 2, style: .continuous))

            if style == .film {
                HStack {
                    filmRail
                    Spacer()
                    filmRail
                }
                .frame(width: frameWidth, height: frameHeight)
            }

            if style == .instant {
                Circle()
                    .fill(.black.opacity(0.12))
                    .frame(width: 3, height: 3)
                    .offset(y: 29)
            }
        }
    }

    private var frameColor: Color {
        switch style {
        case .cleanBlack, .film: return .black
        case .cleanWhite, .instant, .minimal: return .white
        }
    }

    private var frameWidth: CGFloat {
        style == .film ? 52 : 48
    }

    private var frameHeight: CGFloat {
        style == .instant ? 66 : 62
    }

    private var imageWidth: CGFloat {
        switch style {
        case .film: return 34
        case .minimal: return 42
        case .cleanWhite, .cleanBlack, .instant: return 38
        }
    }

    private var imageHeight: CGFloat {
        style == .instant ? 43 : 48
    }

    private var filmRail: some View {
        VStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(.white.opacity(0.42))
                    .frame(width: 3, height: 5)
            }
        }
        .frame(width: 8)
    }
}

private struct FrameValueSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 76, alignment: .leading)

            Slider(value: $value, in: range)

            Text("\(Int(value.rounded()))")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 30, alignment: .trailing)
        }
    }
}

private struct PhotoFrameBackgroundColorPicker: View {
    @Binding var selection: PhotoFrameBackgroundColor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("背景颜色")

            HStack(spacing: 12) {
                ForEach(PhotoFrameBackgroundColor.allCases, id: \.self) { color in
                    let isSelected = color == selection

                    Button {
                        selection = color
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 30, height: 30)
                            .overlay {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                            }
                            .padding(3)
                            .overlay {
                                Circle()
                                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(color.title)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
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
    @ObservedObject var previewStore: CameraPreviewStore
    let watermark: WatermarkPreset
    let styleName: String
    let locationText: String?

    var body: some View {
        ZStack(alignment: alignment) {
            previewBackground

            if watermark.enabled {
                previewWatermark
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            }
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var previewBackground: some View {
        if let image = previewStore.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.52, green: 0.60, blue: 0.62),
                    Color(red: 0.22, green: 0.18, blue: 0.15),
                    Color(red: 0.72, green: 0.66, blue: 0.50)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
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
    @ObservedObject var previewStore: CameraPreviewStore
    let preset: PhotoFramePreset

    var body: some View {
        ZStack {
            previewBackground
                .padding(contentPadding)

            LiveFrameOverlayView(preset: preset)
        }
        .frame(height: 230)
        .background(frameBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(14)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var previewBackground: some View {
        if let image = previewStore.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.72, green: 0.84, blue: 0.90),
                    Color(red: 0.72, green: 0.42, blue: 0.22),
                    Color(red: 0.12, green: 0.13, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var contentPadding: EdgeInsets {
        let border = CGFloat(preset.borderWidth)
        switch preset.style {
        case .cleanWhite, .cleanBlack:
            return EdgeInsets(top: border, leading: border, bottom: border, trailing: border)
        case .instant:
            return EdgeInsets(top: border, leading: border, bottom: border * 3.1, trailing: border)
        case .film:
            return EdgeInsets(top: border * 0.9, leading: border * 1.8, bottom: border * 0.9, trailing: border * 1.8)
        case .minimal:
            let minimalBorder = border * 0.55
            return EdgeInsets(
                top: minimalBorder,
                leading: minimalBorder,
                bottom: minimalBorder,
                trailing: minimalBorder
            )
        }
    }

    private var frameBackground: Color {
        preset.backgroundColor.color.opacity(Double(preset.opacity))
    }
}

private struct PhotoGuidancePreviewView: View {
    @ObservedObject var previewStore: CameraPreviewStore
    let settings: PhotoGuidanceSettings

    var body: some View {
        ZStack(alignment: .topLeading) {
            previewBackground

            GridOverlayView()
                .opacity(0.62)

            VStack(alignment: .leading, spacing: 8) {
                if settings.angleEnabled {
                    GuidancePreviewChip(
                        title: "画面稍微向右",
                        systemImage: "level",
                        tint: .blue
                    )
                }
                if settings.lightEnabled {
                    GuidancePreviewChip(
                        title: "光线偏暗",
                        systemImage: "sun.max.fill",
                        tint: .yellow
                    )
                }
                if settings.compositionEnabled {
                    GuidancePreviewChip(
                        title: "主体可再靠近三分线",
                        systemImage: "viewfinder",
                        tint: .green
                    )
                }
            }
            .padding(12)
        }
        .frame(height: 270)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var previewBackground: some View {
        if let image = previewStore.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.32, green: 0.50, blue: 0.58),
                    Color(red: 0.12, green: 0.20, blue: 0.27)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct GuidancePreviewChip: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint == .yellow ? Color.black.opacity(0.78) : Color.white)
            .padding(.horizontal, 10)
            .frame(minHeight: 32)
            .background(tint.opacity(0.86), in: Capsule())
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

    var settingsIconName: String {
        switch self {
        case .topLeft: return "arrow.up.left"
        case .topRight: return "arrow.up.right"
        case .bottomLeft: return "arrow.down.left"
        case .bottomRight: return "arrow.down.right"
        case .bottomCenter: return "arrow.down.to.line.compact"
        case .custom: return "move.3d"
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
        case .minimal: return "极简"
        }
    }

    var shortTitle: String {
        switch self {
        case .cleanWhite: return "白边"
        case .cleanBlack: return "黑边"
        case .instant: return "拍立得"
        case .film: return "胶片"
        case .minimal: return "极简"
        }
    }
}

private extension PhotoFrameBackgroundColor {
    var title: String {
        switch self {
        case .white: return "白色"
        case .lightGray: return "浅灰"
        case .black: return "黑色"
        case .cream: return "奶油"
        case .pink: return "粉色"
        case .mint: return "薄荷"
        }
    }

    var color: Color {
        switch self {
        case .white: return Color(white: 0.98)
        case .lightGray: return Color(red: 0.88, green: 0.89, blue: 0.91)
        case .black: return Color(white: 0.03)
        case .cream: return Color(red: 0.96, green: 0.84, blue: 0.67)
        case .pink: return Color(red: 0.96, green: 0.84, blue: 0.90)
        case .mint: return Color(red: 0.78, green: 0.94, blue: 0.86)
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
        case .quiet: return "低"
        case .standard: return "中等"
        case .active: return "高"
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

    static func clampedZoom(_ zoom: CGFloat) -> CGFloat {
        min(maxZoom, max(minZoom, zoom))
    }

    static func progress(for zoom: CGFloat) -> CGFloat {
        let clampedZoom = clampedZoom(zoom)
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
        (clampedZoom(zoom) * 10).rounded() / 10
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
