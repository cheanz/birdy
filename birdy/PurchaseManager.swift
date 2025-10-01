import Foundation
import Purchases
import SwiftUI

// Simple manager for one-time purchases (credits) with local credit persistence
@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    // Map product identifiers to credit amounts (edit to match your App Store / RevenueCat setup)
    let productCredits: [String: Int] = [
        "com.yourdomain.birdy.10credits": 10,
        "com.yourdomain.birdy.100credits": 100
    ]

    @Published var offering: Offering?
    @Published var customerInfo: CustomerInfo?
    @Published var isPurchasing: Bool = false
    @Published var localCredits: Int = 0 {
        didSet { saveLocalCredits() }
    }

    private let creditsKey = "birdy_local_credits"

    private init() {
        // load local credits from storage
        self.localCredits = UserDefaults.standard.integer(forKey: creditsKey)

        Task.detached { [weak self] in
            await self?.loadOfferings()
            await self?.refreshCustomerInfo()
        }
    }

    private func saveLocalCredits() {
        UserDefaults.standard.set(localCredits, forKey: creditsKey)
    }

    // Public helper to add credits locally (useful for granting after successful purchase)
    func addLocalCredits(_ amount: Int) {
        localCredits += amount
    }

    func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            await MainActor.run {
                self.offering = offerings.current
            }
        } catch {
            print("Failed to load offerings:", error)
        }
    }

    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            await MainActor.run {
                self.customerInfo = info
            }
        } catch {
            print("Failed to refresh customer info:", error)
        }
    }

    // Purchase a specific package and credit the mapped amount locally.
    func purchase(package: Package) async throws -> CustomerInfo {
        await MainActor.run { self.isPurchasing = true }
        defer { Task { await MainActor.run { self.isPurchasing = false } } }

        let result = try await Purchases.shared.purchase(package: package)
        await MainActor.run {
            self.customerInfo = result.customerInfo

            // credit mapping: look up product id and add mapped credits locally
            let pid = package.product.productIdentifier
            if let creditAmount = productCredits[pid] {
                self.localCredits += creditAmount
            } else {
                // fallback: 10 credits per dollar
                let priceDouble = NSDecimalNumber(decimal: package.product.price as Decimal).doubleValue
                let estimated = Int(round(priceDouble * 10.0))
                self.localCredits += max(estimated, 0)
            }
        }

        return result.customerInfo
    }
}
