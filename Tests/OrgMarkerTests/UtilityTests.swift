//
//  UtilityTests.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 22/06/17.
//
//

import XCTest
@testable import OrgMarker

class UtilityTests: XCTestCase {
    
    func testFirstPattern() throws {
        let grammer = Grammar.main()
        let text = [
            "#+TODO: TODO | DONE",
            "# comment",
            "",
            "* a headline",
            "* headline2",
            "* headline3",
            ].joined(separator: "\n")
        
        let range = text.startIndex..<text.endIndex
        let (p1, mr1) = grammer.firstMatchingPattern(in: text, range: range)!
        
//        print("--> \(pattern.name)")
//        print("--> \(text.substring(with: mr.range))")
        
        XCTAssertEqual("setting", p1.name)
        XCTAssertEqual("#+TODO: TODO | DONE\n", text.substring(with: mr1.range))
        
        let (p2, mr2) = grammer.firstMatchingPattern(named: "headline", in: text, range: range)!
        
        XCTAssertEqual("headline", p2.name)
        XCTAssertEqual("* a headline\n", text.substring(with: mr2.range))
        

    }
    
}
