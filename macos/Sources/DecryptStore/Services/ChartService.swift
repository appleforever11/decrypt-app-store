import Foundation

enum ChartService {
    static func popular() async throws -> ChartResponse.Feed {
        let url = URL(string: "https://rss.marketingtools.apple.com/api/v2/us/apps/top-free/25/apps.json")!
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 25))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw CommandError.setup("Apple’s chart is temporarily unavailable.") }
        return try JSONDecoder().decode(ChartResponse.self, from: data).feed
    }
    static func lookup(id: String) async throws -> LookupResponse.Item {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [URLQueryItem(name: "id", value: id), URLQueryItem(name: "country", value: "us")]
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: components.url!, timeoutInterval: 25))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw CommandError.invalidResponse }
        let result = try JSONDecoder().decode(LookupResponse.self, from: data)
        guard let app = result.results.first, String(app.trackId) == id else { throw CommandError.invalidResponse }
        return app
    }
}
