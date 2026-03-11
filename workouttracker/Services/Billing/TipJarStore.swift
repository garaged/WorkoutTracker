import Foundation
import StoreKit
import Combine

@MainActor
final class TipJarStore: ObservableObject {

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastErrorMessage: String?

    private let productIDs: [String]

    init(productIDs: [String]) {
        self.productIDs = productIDs
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await Product.products(for: productIDs)

            // Keep deterministic ordering matching `productIDs`
            self.products = productIDs.compactMap { id in
                fetched.first(where: { $0.id == id })
            }

            self.lastErrorMessage = products.isEmpty
                ? "Tip options aren’t available yet. Make sure the In-App Purchases exist in App Store Connect."
                : nil
        } catch {
            self.products = []
            self.lastErrorMessage = "Could not load tip options. Please try again."
        }
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try verify(verification)
                // Consumable tips: still finish the transaction.
                await transaction.finish()
                lastErrorMessage = nil
                return true

            case .userCancelled, .pending:
                return false

            @unknown default:
                return false
            }
        } catch {
            lastErrorMessage = "Purchase failed. Please try again."
            return false
        }
    }

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified:
            throw NSError(domain: "TipJarStore", code: 1)
        }
    }
}
