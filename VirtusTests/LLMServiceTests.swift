import XCTest
@testable import Virtus

final class LLMServiceTests: XCTestCase {

    func testSecretManagerLoading() throws {
        let key = SecretManager.geminiAPIKey
        XCTAssertFalse(key.isEmpty, "API Key should not be empty. Make sure Secrets.plist is configured correctly.")
        XCTAssertNotEqual(key, "REPLACE_WITH_YOUR_KEY", "API Key should be replaced with a real value.")
    }

    func testLLMResponseParsing() throws {
        let json = """
        {
          "message": "I have updated your goals.",
          "actions": [
            {
              "updateProfile": {
                "goals": "Increase bench press to 225lbs"
              }
            }
          ]
        }
        """
        
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try decoder.decode(LLMResponse.self, from: data)
        
        XCTAssertEqual(response.message, "I have updated your goals.")
        XCTAssertEqual(response.actions?.count, 1)
        
        if case .updateProfile(let payload) = response.actions?.first {
            XCTAssertEqual(payload.goals, "Increase bench press to 225lbs")
        } else {
            XCTFail("Action should be updateProfile")
        }
    }
}
