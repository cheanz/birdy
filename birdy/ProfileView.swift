import SwiftUI
import RevenueCat

struct ProfileView: View {
    // simple local credit counter persisted in UserDefaults
    @AppStorage("birdy_local_credits") private var credits: Int = 0
    @StateObject private var purchases = PurchaseManager.shared
    @State private var isProcessing: Bool = false
    @State private var alertMessage: String?
    @State private var showToast: Bool = false
    @State private var toastText: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.tint)

                Text("Your Name")
                    .font(.title2)

                Text("Member since 2025")
                    .foregroundColor(.secondary)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Credits")
                        .font(.headline)

                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(credits)")
                            .font(.largeTitle)
                            .bold()
                        Spacer()
                    }
                    Text("Credits are stored locally on this device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGroupedBackground)))

                // Purchases section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Buy Credits")
                        .font(.headline)

                    if purchases.isLoading {
                        Text("Loading…")
                            .foregroundColor(.secondary)
                    } else if purchases.packages.isEmpty {
                        Text("No offerings available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(purchases.packages, id: \.identifier) { pkg in
                            packageRow(pkg)
                                .padding(.vertical, 6)
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGroupedBackground)))

                // Settings: payment & subscription management
                VStack(alignment: .leading, spacing: 8) {
                    Text("Settings")
                        .font(.headline)

                    NavigationLink(destination: PaymentMethodsView()) {
                        HStack {
                            Text("Payment Methods")
                            Spacer()
                            Image(systemName: "creditcard")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }

                    NavigationLink(destination: SubscriptionsView()) {
                        HStack {
                            Text("Subscriptions")
                            Spacer()
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }

                    Button(action: {
                        Task {
                            do {
                                try await PurchaseManager.shared.restorePurchases()
                            } catch {
                                // best-effort: show an alert via setting state (kept simple)
                            }
                        }
                    }) {
                        HStack {
                            Text("Restore Purchases")
                            Spacer()
                        }
                    }
                    .padding(.vertical, 6)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGroupedBackground)))

                Spacer()
            }
            .padding()
            .navigationTitle("Profile")
            .onAppear {
                Task { await purchases.loadOfferings() }
            }
            .overlay(
                Group {
                    if showToast {
                        Text(toastText)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.8)))
                            .foregroundColor(.white)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(1)
                    }
                }
                , alignment: .top
            )
            .alert("Purchase", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func packageRow(_ pkg: RevenueCat.Package) -> some View {
        // compute commonly used values in small, typed steps to help the compiler
        let pid = pkg.storeProduct.productIdentifier
        let priceValue = NSDecimalNumber(decimal: pkg.storeProduct.price as Decimal).doubleValue
    let creditAmount = purchases.productCredits[pid] ?? Int(round(priceValue * Double(purchases.creditsPerDollar)))

        HStack {
            VStack(alignment: .leading) {
                Text("\(creditAmount) credits")
                    .bold()
                Text(pkg.storeProduct.localizedTitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: {
                Task {
                    isProcessing = true
                    do {
                        let added = try await purchases.purchase(pkg)
                        if added > 0 {
                            toastText = "Added \(added) credits"
                            showToast = true
                            // auto-hide after 2 seconds
                            Task {
                                try await Task.sleep(nanoseconds: 2_000_000_000)
                                await MainActor.run { showToast = false }
                            }
                        }
                    } catch {
                        alertMessage = error.localizedDescription
                    }
                    isProcessing = false
                }
            }) {
                Text(pkg.storeProduct.localizedPriceString)
            }
            .disabled(isProcessing || purchases.isPurchasing)
        }
    }
}

#Preview {
    ProfileView()
}
