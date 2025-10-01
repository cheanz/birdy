import Foundation
import RevenueCat
import SwiftUI

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    // Map product identifiers to credit amounts. Update these to match your products.
    let productCredits: [String: Int] = [
        "com.yourdomain.birdy.10credits": 10,
        "com.yourdomain.birdy.100credits": 100
    ]

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
        if let _ = result.customerInfo {
            let pid = package.product.productIdentifier
            let creditsToAdd = productCredits[pid] ?? Int(round(NSDecimalNumber(decimal: package.product.price as Decimal).doubleValue * 10.0))
            let key = "birdy_local_credits"
            let current = UserDefaults.standard.integer(forKey: key)
            UserDefaults.standard.set(current + creditsToAdd, forKey: key)
            return creditsToAdd
        }

        return 0
    }
}
