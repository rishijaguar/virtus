import Foundation

enum GeminiError: Error, LocalizedError {
    case invalidURL
    case serializationError
    case apiError(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL. Please check the endpoint and API key format."
        case .serializationError: return "Failed to process data. The AI response might not be valid JSON."
        case .apiError(let message): return "API Error: \(message)"
        case .invalidResponse: return "Invalid response from server."
        }
    }
}

struct GeminiResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

struct GeminiRequest: Codable {
    struct Content: Codable {
        struct Part: Codable {
            let text: String
        }
        let role: String
        let parts: [Part]
    }
    let contents: [Content]
    let systemInstruction: Content?
}

class GeminiService {
    private let apiKey: String
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    
    init(apiKey: String = SecretManager.geminiAPIKey) {
        // Trimming is crucial as plist strings can sometimes contain hidden newlines
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func sendMessage(messages: [GeminiRequest.Content], systemPrompt: String?) async throws -> String {
        let text = try await fetchResponse(messages: messages, systemPrompt: systemPrompt)
        return text
    }
    
    func sendMessageReturningJSON(messages: [GeminiRequest.Content], systemPrompt: String?) async throws -> LLMResponse {
        let text = try await fetchResponse(messages: messages, systemPrompt: systemPrompt)
        
        // Clean the response if it's wrapped in markdown code blocks
        var cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedText.hasPrefix("```json") {
            cleanedText = cleanedText.replacingOccurrences(of: "```json", with: "")
            if cleanedText.hasSuffix("```") {
                cleanedText = String(cleanedText.dropLast(3))
            }
        } else if cleanedText.hasPrefix("```") {
             cleanedText = cleanedText.replacingOccurrences(of: "```", with: "")
             if cleanedText.hasSuffix("```") {
                 cleanedText = String(cleanedText.dropLast(3))
             }
        }
        
        guard let data = cleanedText.data(using: .utf8) else {
            throw GeminiError.serializationError
        }
        
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(LLMResponse.self, from: data)
        } catch {
            print("Failed to decode LLMResponse: \(error)")
            print("Raw text was: \(cleanedText)")
            throw GeminiError.serializationError
        }
    }

    private func fetchResponse(messages: [GeminiRequest.Content], systemPrompt: String?) async throws -> String {
        guard !apiKey.isEmpty else {
            print("GeminiService Error: API Key is empty.")
            throw GeminiError.apiError("API Key is missing. Check Secrets.plist.")
        }
        
        guard var urlComponents = URLComponents(string: endpoint) else {
            print("GeminiService Error: Could not create URLComponents from endpoint: \(endpoint)")
            throw GeminiError.invalidURL
        }
        
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        
        guard let url = urlComponents.url else {
            print("GeminiService Error: Could not create URL from components. Likely invalid characters in API Key.")
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemInstruction = systemPrompt.map { GeminiRequest.Content(role: "system", parts: [GeminiRequest.Content.Part(text: $0)]) }
        let geminiRequest = GeminiRequest(contents: messages, systemInstruction: systemInstruction)
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(geminiRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Gemini API Error: Status \(httpResponse.statusCode), Body: \(errorBody)")
            throw GeminiError.apiError("Status code: \(httpResponse.statusCode). \(errorBody)")
        }
        
        let decoder = JSONDecoder()
        let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)
        
        guard let text = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw GeminiError.invalidResponse
        }
        
        return text
    }
}


