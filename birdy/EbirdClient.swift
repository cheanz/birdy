import Foundation

struct EbirdObservation: Decodable, Identifiable {
    public let id = UUID()
    public let speciesCode: String?
    public let comName: String?
    public let sciName: String?
    public let obsDt: String?
    public let howMany: Int?
    public let lat: Double?
    public let lng: Double?

    enum CodingKeys: String, CodingKey {
        case speciesCode, comName, sciName, obsDt, howMany, lat, lng
    }
}

enum EbirdError: Error {
    case missingApiKey
    case badUrl
    case httpError(statusCode: Int)
    case noData
}

final class EbirdClient {
    private static var apiKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "EBIRD_API_KEY") as? String
    }

    static func fetchRecentObservations(lat: Double, lng: Double, dist: Int = 10, maxResults: Int = 50, completion: @escaping (Result<[EbirdObservation], Error>) -> Void) {
        guard let key = apiKey, !key.isEmpty else {
            completion(.failure(EbirdError.missingApiKey))
            return
        }

        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "api.ebird.org"
        comps.path = "/v2/data/obs/geo/recent"
        comps.queryItems = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lng", value: String(lng)),
            URLQueryItem(name: "dist", value: String(dist)),
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]

        guard let url = comps.url else {
            completion(.failure(EbirdError.badUrl))
            return
        }

        var req = URLRequest(url: url)
        req.setValue(key, forHTTPHeaderField: "X-eBirdApiToken")

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let err = error { completion(.failure(err)); return }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                completion(.failure(EbirdError.httpError(statusCode: http.statusCode))); return
            }
            guard let data = data else { completion(.failure(EbirdError.noData)); return }
            do {
                let decoder = JSONDecoder()
                let obs = try decoder.decode([EbirdObservation].self, from: data)
                completion(.success(obs))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
