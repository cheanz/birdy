import SwiftUI
import RevenueCat

struct PaymentMethodsView: View {
    @StateObject private var purchases = PurchaseManager.shared

    var body: some View {
        VStack(spacing: 16) {
            Text("Payment Methods")
                .font(.title2)

            Text("Payment methods are managed by the App Store. You can update your cards in your Apple ID settings.")
                .font(.caption)
                .foregroundColor(.secondary)

            if let info = purchases.customerInfo {
                // Display basic entitlement/subscription info as a proxy — RevenueCat doesn't expose cards
                List {
                    Section(header: Text("Entitlements")) {
                        ForEach(Array(info.entitlements.all.keys), id: \.self) { key in
                            Text(key)
                        }
                    }
                }
            } else {
                Text("No purchase info available")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Payment Methods")
        .onAppear {
            Task { await purchases.refreshCustomerInfo() }
        }
    }
}

#Preview {
    NavigationView { PaymentMethodsView() }
}
