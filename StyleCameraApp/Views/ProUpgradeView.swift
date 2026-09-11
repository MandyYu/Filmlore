import SwiftUI

struct ProUpgradeView: View {
    @EnvironmentObject private var proAccess: ProAccessManager

    private let benefits = [
        ProBenefit(icon: "camera.filters", title: "无限自定义风格", detail: "编辑参数并保存属于你的拍摄风格"),
        ProBenefit(icon: "slider.horizontal.3", title: "精细风格调整", detail: "调节曝光、色彩、锐度和胶片质感"),
        ProBenefit(icon: "square.stack.3d.up", title: "专业拍摄模板", detail: "解锁更多版式留白与拍摄信息组合"),
        ProBenefit(icon: "viewfinder", title: "AI 拍照指导", detail: "获得构图、水平、光线和清晰度提醒")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero
                benefitsCard
                purchaseControls
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
        .background(StyleCameraTheme.screenGradient.ignoresSafeArea())
        .navigationTitle("StyleCamera Pro")
        .navigationBarTitleDisplayMode(.inline)
        .tint(StyleCameraTheme.primary)
        .preferredColorScheme(.dark)
        .task {
            guard proAccess.product == nil else { return }
            await proAccess.refresh()
        }
        .alert("StyleCamera Pro", isPresented: messageBinding) {
            Button("好") {
                proAccess.message = nil
            }
        } message: {
            Text(proAccess.message ?? "")
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(StyleCameraTheme.warmGradient)
                .shadow(color: StyleCameraTheme.primary.opacity(0.5), radius: 14)

            Text("StyleCamera Pro")
                .font(.system(size: 28, weight: .bold))

            Text(proAccess.isProUnlocked ? "全部专业功能已解锁" : "一次升级，释放你的创作空间")
                .font(.subheadline)
                .foregroundStyle(StyleCameraTheme.palePink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            LinearGradient(
                colors: [
                    StyleCameraTheme.primary.opacity(0.58),
                    StyleCameraTheme.deepPurple.opacity(0.82),
                    StyleCameraTheme.deepNavy
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
    }

    private var benefitsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(benefits.enumerated()), id: \.element.id) { index, benefit in
                HStack(spacing: 14) {
                    Image(systemName: benefit.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(StyleCameraTheme.orange)
                        .frame(width: 36, height: 36)
                        .background(StyleCameraTheme.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(benefit.title)
                            .font(.subheadline.weight(.semibold))
                        Text(benefit.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)

                if index < benefits.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.horizontal, 14)
        .background(StyleCameraTheme.panelBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(StyleCameraTheme.divider.opacity(0.7), lineWidth: 1)
        }
    }

    private var purchaseControls: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await proAccess.purchase()
                }
            } label: {
                HStack(spacing: 8) {
                    if proAccess.isPurchasing || proAccess.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else if proAccess.isProUnlocked {
                        Image(systemName: "checkmark.seal.fill")
                    }

                    Text(proAccess.purchaseButtonTitle)
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(StyleCameraTheme.primaryGradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(proAccess.isPurchasing || proAccess.isLoading || proAccess.isProUnlocked)
            .opacity(proAccess.isProUnlocked ? 0.72 : 1)

            Button("恢复购买") {
                Task {
                    await proAccess.restorePurchases()
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(StyleCameraTheme.palePink)
            .disabled(proAccess.isPurchasing)

            Text("一次购买，永久解锁。购买由 App Store 安全处理。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            #if DEBUG
            Button(proAccess.isProUnlocked ? "关闭本地 Pro 测试权益" : "启用本地 Pro 测试权益") {
                proAccess.setDebugUnlocked(!proAccess.isProUnlocked)
            }
            .font(.caption)
            .foregroundStyle(StyleCameraTheme.cyan)
            .padding(.top, 6)
            #endif
        }
    }

    private var messageBinding: Binding<Bool> {
        Binding(
            get: { proAccess.message != nil },
            set: { isPresented in
                if !isPresented {
                    proAccess.message = nil
                }
            }
        )
    }
}

private struct ProBenefit: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}
