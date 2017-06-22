//
//  InlineTests.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 27/03/17.
//
//

import XCTest
@testable import OrgMarker

class InlineTests: XCTestCase {
    var text: String!
    var lines: [String]!
    
    override func setUp() {
        super.setUp()
    }
    
    func testBasicSyntax() throws {
        let syntax = [
            ("~awesome~", "code"),
            ("=awesome=", "verbatim"),
            ("*awesome*", "bold"),
            ("/awesome/", "italic"),
            ("_awesome_", "underline"),
            ("+awesome+", "strikeThrough"),
            ("[[awesome][www.orgmode.org]]", "link"),
            ]
        for (text, name) in syntax {
            let line = "org-mode is \(text). smiley face 😀."
            expect(mark(line)[0],
                   to: haveMark(name, to: haveValue(text, on: line)))
        }
    }
    
    func testComplexLink() {
        let text = "This is an [[awesome website][www.orgmode.org/awesome/tool]]."
        let m = mark(text)[0]
        XCTAssertEqual(1, m.marks.count)
        expect(m, to: haveMark("link"))
    }
    
}
