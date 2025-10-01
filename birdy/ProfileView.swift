import SwiftUI


struct ProfileView: View {
    @StateObject private var purchases = PurchaseManager.shared
    @State private var showAlert = false
    @State private var alertMessage = ""

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

                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Credits")
                                .font(.headline)
                            Text("One-time purchase to buy credits used in the app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(purchases.localCredits)")
                            .bold()
                    }
                    // List all available packages for purchase
                    if let pkgs = purchases.offering?.availablePackages, !pkgs.isEmpty {
                        ForEach(pkgs, id: \ .identifier) { pkg in
                            let pid = pkg.product.productIdentifier
                            let credits = purchases.productCredits[pid] ?? Int(round(NSDecimalNumber(decimal: pkg.product.price as Decimal).doubleValue * 10.0))
                            Button(action: {
                                Task {
                                    do {
                                        _ = try await purchases.purchase(package: pkg)
                                    } catch {
                                        alertMessage = error.localizedDescription
                                        showAlert = true
                                    }
                                }
                            }) {
                                HStack {
                                    Text("Buy \(credits) credits")
                                    Spacer()
                                    Text(pkg.product.priceLocale.currencySymbol ?? "")
                                        + Text(String(format: "%.2f", NSDecimalNumber(decimal: pkg.product.price as Decimal).doubleValue))
                                }
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(purchases.isPurchasing)
                        }
                    } else {
                        Text("Loading purchase info…")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGroupedBackground)))

                Spacer()
            }
            .padding()
            .navigationTitle("Profile")
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Purchase"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .task {
                await purchases.loadOfferings()
                await purchases.refreshCustomerInfo()
            }
        }
    }
}

#Preview {
    ProfileView()
}
