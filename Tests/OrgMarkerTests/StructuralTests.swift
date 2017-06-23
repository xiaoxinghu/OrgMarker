//
//  StructuralTests.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 24/03/17.
//
//

import XCTest
@testable import OrgMarker

fileprivate func m(_ lines: [String]) -> [Mark] {
    let marker = Marker()
    guard case .success(let marks) = marker.mark(lines.joined(separator: "\n")) else {
        XCTFail()
        return []
    }
    return marks
}

class StructuralTests: XCTestCase {
    
    func testList() throws {
        // TODO: implement test
        let marks = m([
            "- list item",
            "- list item",
            "",
            "- list item",
            "  - list item",
            ])
        XCTAssertEqual(marks.count, 3)
    }
    
    func testTable() {
        // TODO: implement test
    }
    
    func testBlock() {
        // TODO: implement test
        let marks = m([
            "#+begin_src swift",
            "print(\"hello world\")",
            "#+end_src",
            ])
        XCTAssertEqual(marks.count, 1)
        let mark = marks[0]
        
        expect(mark, to: beNamed("block"))
    }
    
    func testInvalidBlock() {
        // TODO: implement test
    }
    
    func testDrawer() {
        // TODO: implement test
    }
    
    func testInvalidDrawer() {
        // TODO: implement test
    }
    
    func testInBufferSetting() {
        // TODO: implement test
    }
    
}
