import SwiftUI
import RevenueCat

struct ProfileView: View {
    @State private var offerings: Offerings?
    @State private var credits: Int = UserDefaults.standard.integer(forKey: "credits")
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
                                let result = try await Purchases.shared.purchase(package: package)
                                if result.customerInfo.entitlements.active.isEmpty {
                                    // Consumable: just grant credits
                                    credits += 10
                                    UserDefaults.standard.set(credits, forKey: "credits")
                                    message = "Added 10 credits!"
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
