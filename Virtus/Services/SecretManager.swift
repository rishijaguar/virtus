import Foundation

enum SecretManager {
    static var geminiAPIKey: String {
        guard let filePath = Bundle.main.path(forResource: "Secrets", ofType: "plist") else {
            print("Secrets.plist not found. Make sure you've added it to the project.")
            return ""
        }
        
        let plist = NSDictionary(contentsOfFile: filePath)
        guard let value = plist?.object(forKey: "GEMINI_API_KEY") as? String else {
            print("GEMINI_API_KEY not found in Secrets.plist.")
            return ""
        }
        
        if value == "REPLACE_WITH_YOUR_KEY" {
            print("Please replace REPLACE_WITH_YOUR_KEY in Secrets.plist with your actual Gemini API key.")
            return ""
        }
        
        return value
    }
}
