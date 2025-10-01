import SwiftUI
import RevenueCat

struct SubscriptionsView: View {
    @StateObject private var purchases = PurchaseManager.shared
    @State private var isProcessing: Bool = false
    @State private var alertMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            Text("Subscriptions & Entitlements")
                .font(.title2)

            if let info = purchases.customerInfo {
                List {
                    Section(header: Text("Active Entitlements")) {
                        ForEach(info.entitlements.all.filter { $0.value.isActive }, id: \.(key)) { key, ent in
                            VStack(alignment: .leading) {
                                Text(key)
                                    .bold()
                                if let exp = ent.latestPurchaseDate {
                                    Text("Purchased: \(exp, formatter: DateFormatter.short)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("No subscription information available")
                    .foregroundColor(.secondary)
            }

            Button("Restore Purchases") {
                Task {
                    isProcessing = true
                    do {
                        try await purchases.restorePurchases()
                    } catch {
                        alertMessage = error.localizedDescription
                    }
                    isProcessing = false
                }
            }
            .disabled(isProcessing)
            .padding()

            Spacer()
        }
        .padding()
        .navigationTitle("Subscriptions")
        .onAppear {
            Task { await purchases.refreshCustomerInfo() }
        }
        .alert("Error", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }
}

private extension DateFormatter {
    static var short: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }
}

#Preview {
    NavigationView { SubscriptionsView() }
}
