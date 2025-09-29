import SwiftUI

struct SearchView: View {
    @State private var query: String = ""

    var body: some View {
        NavigationView {
            VStack {
                TextField("Search birds, locations...", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                Spacer()
                Text(query.isEmpty ? "Type to search." : "Searching for \"\(query)\"...")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .navigationTitle("Search")
        }
    }
}

#Preview {
    SearchView()
}
