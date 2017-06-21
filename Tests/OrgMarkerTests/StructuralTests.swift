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
        var g = Grammar.main()
        g.patterns.removeAll()
        print("\(g.patterns.count)")
        let g2 = Grammar.main()
        print("\(g2.patterns.count)")
    }
    
    func testBlock() {
        XCTFail("not implemented")
    }
    
    func testInvalidBlock() {
        XCTFail("not implemented")
    }
    
    func testDrawer() {
        XCTFail("not implemented")
    }
    
    func testInvalidDrawer() {
        XCTFail("not implemented")
    }
    
    func testInBufferSetting() {
        XCTFail("not implemented")
    }
    
}
