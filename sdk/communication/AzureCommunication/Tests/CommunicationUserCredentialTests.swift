// --------------------------------------------------------------------------
//
// Copyright (c) Microsoft Corporation. All rights reserved.
//
// The MIT License (MIT)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the ""Software""), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
//
// --------------------------------------------------------------------------

import XCTest

#if canImport(AzureCommunication)
@testable import AzureCommunication
#endif
#if canImport(AzureCore)
@testable import AzureCore
#endif

enum FetchTokenError: Error {
    case badRequest(String)
}

class CommunicationUserCredentialTests: XCTestCase {
    private let sampleToken =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjMyNTAzNjgwMDAwfQ.9i7FNNHHJT8cOzo-yrAUJyBSfJ-tPPk2emcHavOEpWc"
    private let sampleTokenExpiry: Double = 32_503_680_000
    private let sampleExpiredToken =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjEwMH0.1h_scYkNp-G98-O4cW6KvfJZwiz54uJMyeDACE4nypg"

    private var fetchTokenCallCount: Int = 0

    override func setUp() {
        super.setUp()

        fetchTokenCallCount = 0
    }

    func fetchTokenSync(completionHandler: TokenRefreshOnCompletion) {
        fetchTokenCallCount += 1

        let newToken = sampleToken
        completionHandler(newToken, nil)
    }

    func fetchTokenSyncWithError(completionHandler: TokenRefreshOnCompletion) {
        fetchTokenCallCount += 1

        completionHandler(nil, FetchTokenError.badRequest("Error while fetching token"))
    }

    func fetchTokenAsync(completionHandler: @escaping TokenRefreshOnCompletion) {
        fetchTokenCallCount += 1

        func getTokenFromServer(completionHandler: @escaping (String) -> Void) {
            // Delay to simulate getting token from server async
            
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3) {
                completionHandler(self.sampleToken)
            }
        }

        getTokenFromServer { newToken in
            completionHandler(newToken, nil)
        }
    }

    func test_DecodesToken() throws {
        let userCredential = try CommunicationUserCredential(token: sampleToken)
        userCredential.token { (accessToken: CommunicationAccessToken?, error: Error?) in
            XCTAssertNil(error)
            XCTAssertEqual(accessToken?.token, self.sampleToken)
            XCTAssertEqual(accessToken?.expiresOn.timeIntervalSince1970, self.sampleTokenExpiry)
        }
    }

    func test_ThrowsIfInvalidToken() throws {
        let invalidTokens = ["foo", "foo.bar", "foo.bar.foobar"]

        try invalidTokens.forEach { invalidToken in
            XCTAssertThrowsError(try CommunicationUserCredential(token: invalidToken))
        }
    }
    
    func test_ThrowsIfMalformedTokenWithCompletion() {
        let expectation = XCTestExpectation()
        let invalidTokens = "foo"
        
        let userCredential = CommunicationUserCredential(
            initialToken: invalidTokens,
            refreshProactively: true,
            tokenRefresher: fetchTokenSync)

        userCredential.token { (token, error) in
            XCTAssertNil(token)
            XCTAssertNotNil(error)
            XCTAssertEqual(error?.localizedDescription.contains("Token is not formatted correctly."), true)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2)
    }
    
    func test_ThrowsIfInvalidTokenWithCompleton() {
        let expectation = XCTestExpectation()
        let invalidTokens = "foo.bar.foobar"
        
        let userCredential = CommunicationUserCredential(
            initialToken: invalidTokens,
            refreshProactively: true,
            tokenRefresher: fetchTokenSync)

        userCredential.token { (token, error) in
            XCTAssertNil(token)
            XCTAssertNotNil(error)
            XCTAssertEqual(error?.localizedDescription.contains("Can't convert base64Data to base64AsString."), true)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2)
    }
    
    func test_RefreshTokenProactively_TokenAlreadyExpired() {
        let expectation = XCTestExpectation()

        let userCredential = CommunicationUserCredential(
            initialToken: sampleExpiredToken,
            refreshProactively: true,
            tokenRefresher: fetchTokenSync
        )

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
            userCredential.token { (accessToken: CommunicationAccessToken?, error: Error?) in
                XCTAssertNotNil(accessToken)
                XCTAssertNil(error)
                XCTAssertEqual(accessToken?.token, self.sampleToken)
                XCTAssertEqual(self.fetchTokenCallCount, 1)

                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2)
    }

    func test_RefreshTokenProactively_FetchTokenReturnsError() {
        let expectation = XCTestExpectation()

        let userCredential = CommunicationUserCredential(
            initialToken: sampleExpiredToken,
            refreshProactively: true,
            tokenRefresher: fetchTokenSyncWithError
        )

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
            userCredential.token { (accessToken: CommunicationAccessToken?, error: Error?) in
                XCTAssertNotNil(error)
                XCTAssertEqual(error.debugDescription.contains("Error while fetching token"), true)
                XCTAssertNil(accessToken)
                XCTAssertEqual(self.fetchTokenCallCount, 2)

                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2)
    }

    func test_RefreshTokenProactively_TokenExpiringSoon() {
        let testCases = [1, 9]

        let expectation = XCTestExpectation()
        let semaphore = DispatchSemaphore(value: 1)

        testCases.forEach { minutes in
            semaphore.wait()
            setUp()

            let expiringToken = generateTokenValidForMinutes(minutes)

            let userCredential = CommunicationUserCredential(
                initialToken: expiringToken,
                refreshProactively: true,
                tokenRefresher: fetchTokenSync
            )

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
                userCredential.token { (accessToken: CommunicationAccessToken?, _: Error?) in
                    XCTAssertNotNil(accessToken)
                    XCTAssertEqual(accessToken?.token, self.sampleToken)

                    userCredential.token { (accessToken: CommunicationAccessToken?, _: Error?) in
                        XCTAssertNotNil(accessToken)
                        XCTAssertEqual(accessToken?.token, self.sampleToken)
                        XCTAssertEqual(self.fetchTokenCallCount, 1)

                        if minutes == testCases.last {
                            expectation.fulfill()
                        }

                        semaphore.signal()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: 2)
    }

    func test_RefreshTokenOnDemand_SyncRefresh() {
        let expectation = XCTestExpectation()

        let expectedToken = sampleToken
        let expectedTokenExpiry = sampleTokenExpiry

        let userCredential = CommunicationUserCredential(
            initialToken: sampleExpiredToken,
            refreshProactively: false,
            tokenRefresher: fetchTokenSync
        )

        DispatchQueue.global(qos: .utility).async {
            userCredential.token { (accessToken: CommunicationAccessToken?, error: Error?) in
                XCTAssertNotNil(accessToken)
                XCTAssertNil(error)
                XCTAssertEqual(accessToken?.token, expectedToken)
                XCTAssertEqual(accessToken?.expiresOn.timeIntervalSince1970, expectedTokenExpiry)

                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1)
    }

    func test_RefreshTokenOnDemand_AsyncRefresh() {
        let expectation = XCTestExpectation()

        let expectedToken = sampleToken
        let expectedTokenExpiry = sampleTokenExpiry

        let userCredential = CommunicationUserCredential(
            initialToken: sampleExpiredToken,
            refreshProactively: false,
            tokenRefresher: fetchTokenAsync
        )

        DispatchQueue.global(qos: .utility).async {
            userCredential.token { (accessToken: CommunicationAccessToken?, error: Error?) in
                XCTAssertNotNil(accessToken)
                XCTAssertNil(error)
                XCTAssertEqual(accessToken?.token, expectedToken)
                XCTAssertEqual(accessToken?.expiresOn.timeIntervalSince1970, expectedTokenExpiry)

                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5)
    }

    private func generateTokenValidForMinutes(_ minutes: Int) -> String {
        let expiresOn = Date().addingTimeInterval(TimeInterval(60 * minutes)).timeIntervalSince1970
        let tokenString = "{\"exp\": \(Int(expiresOn))}"

        let tokenStringData = tokenString.data(using: .ascii)!

        // swiftlint:disable line_length
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.\(tokenStringData.base64EncodedString()).adM-ddBZZlQ1WlN3pdPBOF5G4Wh9iZpxNP_fSvpF4cWs"
        // swiftlint:enable line_length
    }
}
