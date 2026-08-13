import Foundation
import Testing
@testable import CoCo

struct UserModelTests {
    @Test
    func decodesMemberWithLinkedProviders() throws {
        let json = """
        {
          "id": "10000000-0000-0000-0000-000000000001",
          "displayName": "노을러너",
          "accountType": "MEMBER",
          "linkedProviders": ["NAVER"]
        }
        """

        let user = try JSONDecoder().decode(User.self, from: Data(json.utf8))

        #expect(user.displayName == "노을러너")
        #expect(user.accountType == .member)
        #expect(user.linkedProviders == [.naver])
    }

    @Test
    func decodesGuestWithEmptyProviders() throws {
        let json = """
        {
          "id": "10000000-0000-0000-0000-000000000002",
          "displayName": "게스트 러너 A1B2",
          "accountType": "GUEST",
          "linkedProviders": []
        }
        """

        let user = try JSONDecoder().decode(User.self, from: Data(json.utf8))

        #expect(user.accountType == .guest)
        #expect(user.linkedProviders.isEmpty)
    }

    @Test
    func toleratesResponsesWithoutLinkedProviders() throws {
        let json = """
        {
          "id": "10000000-0000-0000-0000-000000000003",
          "displayName": "이전 응답",
          "accountType": "GUEST"
        }
        """

        let user = try JSONDecoder().decode(User.self, from: Data(json.utf8))

        #expect(user.linkedProviders.isEmpty)
    }

    @Test
    func providerPathMatchesServerRoutes() {
        #expect(AuthProvider.naver.pathValue == "naver")
        #expect(AuthProvider.kakao.pathValue == "kakao")
        #expect(AuthProvider.naver.displayName == "네이버")
        #expect(AuthProvider.kakao.displayName == "카카오")
    }
}
