//
//  OpenAIService.swift
//  EZMilitaryService
//
//  Created by Allen Su on 5/29/25.
//

import Foundation

class AnthropicService: ObservableObject {
    private let apiKey = Config.anthropicApiKey
    private let endpoint = "https://api.anthropic.com/v1/messages"
    
    @Published var inferredVillage: String?
    @Published var isLoading = false
    @Published var error: Error?
    
    func inferVillage(from address: String) async {
        isLoading = true
        inferredVillage = nil
        error = nil
        
        let prompt = """
        You are an assistant helping categorize addresses in Taiwan into their correct administrative villages (里). Given a full address in Traditional Chinese that includes only the city (市), district (區), road name, lane, and house number—but not the village (里)—your task is to intelligently infer the correct village using known postal data and nearby address patterns.

        You do not have access to external APIs or real-time lookups, but you should reason based on commonly known village boundaries and examples.

        Return only the village name (e.g., "西平里") as your final answer.

        Address: \(address)
        """
        
        let body: [String: Any] = [
            "model": "claude-3-opus-20240229",
            "max_tokens": 50,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            DispatchQueue.main.async {
                self.error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "JSON encoding failed"])
                self.isLoading = false
            }
            return
        }
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.httpBody = jsonData
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            print("Anthropic response: \(String(data: data, encoding: .utf8) ?? "no data")")
            let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            DispatchQueue.main.async {
                self.inferredVillage = response.content.first?.text.trimmingCharacters(in: .whitespacesAndNewlines)
                self.isLoading = false
            }
        } catch {
            print("Decoding error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("Key '\(key)' not found:", context.debugDescription)
                case .typeMismatch(let type, let context):
                    print("Type '\(type)' mismatch:", context.debugDescription)
                case .valueNotFound(let type, let context):
                    print("Value of type '\(type)' not found:", context.debugDescription)
                case .dataCorrupted(let context):
                    print("Data corrupted:", context.debugDescription)
                @unknown default:
                    print("Unknown decoding error")
                }
            }
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
        }
    }
}

struct AnthropicResponse: Codable {
    let content: [ContentBlock]
    
    struct ContentBlock: Codable {
        let text: String
        let type: String
    }
}
