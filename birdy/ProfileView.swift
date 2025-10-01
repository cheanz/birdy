import SwiftUI

struct ProfileView: View {
    // simple local credit counter persisted in UserDefaults
    @AppStorage("birdy_local_credits") private var credits: Int = 0

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
