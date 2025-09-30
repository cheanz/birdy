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
        // Step 1: search for the best matching page
        guard let searchQuery = speciesName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(.failure(WikimediaError.badUrl)); return
        }

        let searchURLString = "https://en.wikipedia.org/w/api.php?action=query&list=search&format=json&srsearch=\(searchQuery)&srlimit=1"
        guard let searchURL = URL(string: searchURLString) else { completion(.failure(WikimediaError.badUrl)); return }

        URLSession.shared.dataTask(with: searchURL) { data, response, error in
            if let e = error { completion(.failure(WikimediaError.networkError(e))); return }
            guard let data = data else { completion(.failure(WikimediaError.noImageFound)); return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let query = json["query"] as? [String: Any],
                   let search = query["search"] as? [[String: Any]],
                   let first = search.first,
                   let pageid = first["pageid"] as? Int {
                    // Step 2: request page image info by pageid (prefer original, fallback to thumbnail)
                    fetchImageForPageid(pageid, completion: completion)
                    return
                }
                // If search didn't return results, also try looking up by titles directly (fallback)
                fetchImageForTitle(speciesName, completion: completion)
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private static func fetchImageForPageid(_ pageid: Int, completion: @escaping (Result<URL, Error>) -> Void) {
        let urlString = "https://en.wikipedia.org/w/api.php?action=query&format=json&prop=pageimages&piprop=original|thumbnail&pageids=\(pageid)&pithumbsize=500"
        guard let url = URL(string: urlString) else { completion(.failure(WikimediaError.badUrl)); return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let e = error { completion(.failure(WikimediaError.networkError(e))); return }
            guard let data = data else { completion(.failure(WikimediaError.noImageFound)); return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let query = json["query"] as? [String: Any],
                   let pages = query["pages"] as? [String: Any] {
                    for (_, page) in pages {
                        if let pageDict = page as? [String: Any] {
                            if let original = pageDict["original"] as? [String: Any], let source = original["source"] as? String, let imgUrl = URL(string: source) {
                                completion(.success(imgUrl)); return
                            }
                            if let thumbnail = pageDict["thumbnail"] as? [String: Any], let thumb = thumbnail["source"] as? String, let imgUrl = URL(string: thumb) {
                                completion(.success(imgUrl)); return
                            }
                        }
                    }
                }
                completion(.failure(WikimediaError.noImageFound))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private static func fetchImageForTitle(_ title: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { completion(.failure(WikimediaError.badUrl)); return }
        let urlString = "https://en.wikipedia.org/w/api.php?action=query&prop=pageimages&format=json&piprop=original|thumbnail&titles=\(encoded)&pithumbsize=500"
        guard let url = URL(string: urlString) else { completion(.failure(WikimediaError.badUrl)); return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let e = error { completion(.failure(WikimediaError.networkError(e))); return }
            guard let data = data else { completion(.failure(WikimediaError.noImageFound)); return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let query = json["query"] as? [String: Any],
                   let pages = query["pages"] as? [String: Any] {
                    for (_, page) in pages {
                        if let pageDict = page as? [String: Any] {
                            if let original = pageDict["original"] as? [String: Any], let source = original["source"] as? String, let imgUrl = URL(string: source) {
                                completion(.success(imgUrl)); return
                            }
                            if let thumbnail = pageDict["thumbnail"] as? [String: Any], let thumb = thumbnail["source"] as? String, let imgUrl = URL(string: thumb) {
                                completion(.success(imgUrl)); return
                            }
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
