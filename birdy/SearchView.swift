import SwiftUI

struct SearchView: View {
    @State private var query: String = ""
    @State private var observations: [EbirdObservation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Demo coordinate: San Francisco
    private let demoLat = 37.7749
    private let demoLng = -122.4194

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Search birds, locations...", text: $query)
                        .textFieldStyle(.roundedBorder)
                    Button("Search") { performSearch() }
                        .disabled(isLoading)
                }
                .padding()

                if isLoading {
                    ProgressView("Loading...")
                        .padding()
                }

                if let err = errorMessage {
                    Text(err)
                        .foregroundColor(.red)
                        .padding([.leading, .trailing])
                }

                List(observations) { obs in
                    VStack(alignment: .leading) {
                        Text(obs.comName ?? "Unknown")
                            .font(.headline)
                        Text(obs.sciName ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let dt = obs.obsDt {
                            Text(dt)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .navigationTitle("Search")
        }
    }

    private func performSearch() {
        isLoading = true
        errorMessage = nil
        observations = []

        EbirdClient.fetchRecentObservations(lat: demoLat, lng: demoLng) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let obs):
                    observations = obs
                case .failure(let err):
                    if case EbirdError.missingApiKey = err {
                        errorMessage = "Missing EBIRD_API_KEY in Info.plist"
                    } else {
                        errorMessage = "Error: \(err.localizedDescription)"
                    }
                }
            }
        }
    }
}

#Preview {
    SearchView()
}

