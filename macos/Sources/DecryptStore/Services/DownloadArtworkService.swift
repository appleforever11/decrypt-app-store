import Foundation

enum DownloadArtworkService {
    static func lookup(appID: Int?, bundleID: String?) async -> LookupResponse.Item? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        if let appID { components.queryItems = [URLQueryItem(name: "id", value: String(appID))] }
        else if let bundleID, !bundleID.isEmpty { components.queryItems = [URLQueryItem(name: "bundleId", value: bundleID)] }
        else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: components.url!, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(LookupResponse.self, from: data).results.first
        } catch { return nil }
    }
}
