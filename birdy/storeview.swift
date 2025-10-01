import SwiftUI
import RevenueCat

struct StoreView: View {
    @State private var offerings: Offerings?
    @State private var credits: Int = UserDefaults.standard.integer(forKey: "birdy_local_credits")
    @State private var message: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("GoBirdy Store")
                .font(.title.bold())

            Text("Credits: \(credits)")
                .font(.headline)

            if let package = offerings?.current?.package(identifier: "10credits") {
                VStack(spacing: 10) {
                    Text("Buy 10 Credits")
                    Text(package.storeProduct.localizedPriceString)
                        .font(.title2.bold())

                    Button("Buy Now") {
                        Task {
                            do {
                                // Use the central PurchaseManager so crediting logic is consistent and
                                // only applied when the manager confirms a successful purchase.
                                let added = try await PurchaseManager.shared.purchase(package)
                                if added > 0 {
                                    // keep local UI state in sync with the manager's persistent counter
                                    credits = UserDefaults.standard.integer(forKey: "birdy_local_credits")
                                    message = "Added \(added) credits!"
                                } else {
                                    message = "Purchase completed but no credits were granted."
                                }
                            } catch {
                                message = "Purchase failed: \(error.localizedDescription)"
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text("Loading products…")
            }

            if let msg = message {
                Text(msg)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .task {
            do {
                offerings = try await Purchases.shared.offerings()
            } catch {
                message = "Failed to load offerings: \(error.localizedDescription)"
            }
        }
    }
}
