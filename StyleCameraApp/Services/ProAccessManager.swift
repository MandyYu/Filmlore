import StoreKit
import SwiftUI

@MainActor
final class ProAccessManager: ObservableObject {
    static let productID = "com.mandy.stylecamera.pro.lifetime"

    @Published private(set) var isProUnlocked = false
    @Published private(set) var hasLoadedEntitlement = false
    @Published private(set) var product: Product?
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published var message: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = observeTransactions()
        Task {
            await refresh()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var purchaseButtonTitle: String {
        if isProUnlocked {
            return "已解锁 StyleCamera Pro"
        }
        if let product {
            return "立即升级 · \(product.displayPrice)"
        }
        return "立即升级"
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            product = try await Product.products(for: [Self.productID]).first
            await refreshEntitlement()
        } catch {
            await refreshEntitlement()
        }
    }

    func purchase() async {
        guard !isProUnlocked else { return }
        if product == nil {
            await refresh()
        }
        guard let product else {
            message = "暂时无法获取商品信息，请稍后重试。"
            return
        }

        isPurchasing = true
        message = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await refreshEntitlement()
                if isProUnlocked {
                    message = "StyleCamera Pro 已成功解锁。"
                }
            case .pending:
                message = "购买正在等待确认，确认后会自动解锁。"
            case .userCancelled:
                break
            @unknown default:
                message = "购买状态暂时无法确认，请稍后重试。"
            }
        } catch {
            message = "购买未完成，请稍后重试。"
        }
    }

    func restorePurchases() async {
        isPurchasing = true
        message = nil
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshEntitlement()
            message = isProUnlocked ? "已恢复 StyleCamera Pro。" : "没有找到可恢复的购买。"
        } catch {
            message = "恢复购买失败，请稍后重试。"
        }
    }

    private func refreshEntitlement() async {
        var hasEntitlement = false

        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.productID == Self.productID,
                  transaction.revocationDate == nil else {
                continue
            }
            hasEntitlement = true
            break
        }

        #if DEBUG
        isProUnlocked = hasEntitlement || UserDefaults.standard.bool(forKey: "StyleCamera.debugProUnlocked")
        #else
        isProUnlocked = hasEntitlement
        #endif
        hasLoadedEntitlement = true
    }

    private func observeTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard case let .verified(transaction) = result else { continue }
                await transaction.finish()
                await self.refreshEntitlement()
            }
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case let .verified(value):
            return value
        case .unverified:
            throw ProPurchaseError.failedVerification
        }
    }

    #if DEBUG
    func setDebugUnlocked(_ unlocked: Bool) {
        UserDefaults.standard.set(unlocked, forKey: "StyleCamera.debugProUnlocked")
        isProUnlocked = unlocked
        hasLoadedEntitlement = true
        message = unlocked ? "已启用本地 Pro 测试权益。" : "已关闭本地 Pro 测试权益。"
    }
    #endif
}

private enum ProPurchaseError: Error {
    case failedVerification
}
