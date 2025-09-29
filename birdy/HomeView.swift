import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Welcome to Birdy")
                    .font(.largeTitle)
                    .bold()

                Text("This is the Home tab.")
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomeView()
}
