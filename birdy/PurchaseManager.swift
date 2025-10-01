import Foundation
import RevenueCat
import SwiftUI

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    // Map product identifiers to credit amounts. Update these to match your App Store Connect product IDs.
    // NOTE: I used the repository owner "cheanz" to form example product IDs below. Replace these
    // with the exact product identifiers you create in App Store Connect (or your StoreKit config).
    let productCredits: [String: Int] = [
        "com.cheanz.birdy.10credits": 10,
        "com.cheanz.birdy.100credits": 100
    ]

    // Conversion rate used when a product id is not mapped explicitly:
    // 1 dollar (USD) -> creditsPerDollar credits
    let creditsPerDollar: Int = 10

    @Published var packages: [Package] = []
    @Published var isLoading: Bool = false
    @Published var isPurchasing: Bool = false

    private init() {
        Task { await loadOfferings() }
    }

    func loadOfferings() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            if let current = offerings.current {
                self.packages = current.availablePackages
            } else {
                self.packages = []
            }
        } catch {
            print("PurchaseManager: loadOfferings error:\(error)")
            self.packages = []
        }
    }

    // Purchase the package and return how many credits were locally added.
    func purchase(_ package: Package) async throws -> Int {
        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await Purchases.shared.purchase(package: package)

        // on successful purchase, credit the local counter in UserDefaults and return amount
        // `result.customerInfo` is non-optional when purchase completes successfully, so
        // treat this as confirmation and credit the mapped amount.
    let pid = package.storeProduct.productIdentifier
    let priceValue = NSDecimalNumber(decimal: package.storeProduct.price as Decimal).doubleValue
    let creditsToAdd = productCredits[pid] ?? Int(round(priceValue * Double(creditsPerDollar)))
        let key = "birdy_local_credits"
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + creditsToAdd, forKey: key)
        return creditsToAdd

        return 0
    }
}
