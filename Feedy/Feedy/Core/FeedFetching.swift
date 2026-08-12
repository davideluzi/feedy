import Foundation

protocol FeedFetching {
    func fetch(url: URL) async throws -> Data
}

struct URLSessionFetcher: FeedFetching {
    func fetch(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Feedy/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
