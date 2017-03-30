import XCTest
@testable import SwiftZip

class SwiftZipTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(SwiftZip().text, "Hello, World!")
    }


    static var allTests : [(String, (SwiftZipTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
