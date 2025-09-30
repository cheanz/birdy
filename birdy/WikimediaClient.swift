import Foundation

enum WikimediaError: Error {
    case badUrl
    case noImageFound
    case networkError(Error)
}

final class WikimediaClient {
    /// Fetch a suitable image URL for a species by searching Wikimedia/Wikipedia.
    /// This performs a search and then asks for page image info.
    static func fetchImageURL(for speciesName: String, completion: @escaping (Result<URL, Error>) -> Void) {
        // Search Wikipedia for the species name
        let encoded = speciesName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? speciesName
        let searchUrlString = "https://en.wikipedia.org/w/api.php?action=query&prop=pageimages&format=json&piprop=original&titles=\(encoded)"
        guard let url = URL(string: searchUrlString) else { completion(.failure(WikimediaError.badUrl)); return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let e = error { completion(.failure(WikimediaError.networkError(e))); return }
            guard let data = data else { completion(.failure(WikimediaError.noImageFound)); return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let query = json["query"] as? [String: Any],
                   let pages = query["pages"] as? [String: Any] {
                    for (_, page) in pages {
                        if let pageDict = page as? [String: Any], let original = pageDict["original"] as? [String: Any], let source = original["source"] as? String, let imgUrl = URL(string: source) {
                            completion(.success(imgUrl)); return
                        }
                    }
                }
                completion(.failure(WikimediaError.noImageFound))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
