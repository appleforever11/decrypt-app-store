import Foundation

enum ArtworkService {
    static func fetch(ids: [Int]) async -> [Int: URL] {
        guard !ids.isEmpty else { return [:] }
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [URLQueryItem(name: "id", value: ids.map(String.init).joined(separator: ","))]
        guard let url = components.url else { return [:] }
        do {
            var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [:] }
            let result = try JSONDecoder().decode(ArtworkResponse.self, from: data)
            return Dictionary(result.results.compactMap { item in (item.artworkUrl512 ?? item.artworkUrl100).map { (item.trackId, $0) } }, uniquingKeysWith: { first, _ in first })
        } catch { return [:] }
    }
}
