import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.tint)

                Text("Your Name")
                    .font(.title2)

                Text("Member since 2025")
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView()
}
