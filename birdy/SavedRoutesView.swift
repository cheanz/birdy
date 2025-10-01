import SwiftUI
import MapKit

struct SavedRoutesView: View {
    @EnvironmentObject var store: RoutesStore

    var body: some View {
        NavigationView {
            List {
                if store.savedRoutes.isEmpty {
                    Text("No saved routes yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(store.savedRoutes) { r in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(r.name)
                                Text(r.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Show") {
                                store.selectedRouteID = r.id
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .padding(.trailing, 8)
                            Button("Delete") {
                                store.deleteRoute(id: r.id)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Saved Routes")
        }
    }
}

#Preview {
    SavedRoutesView()
}
