//
//  ReleaseTests.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 23/06/17.
//
//

import XCTest
import OrgMarker

class ReleaseTests: XCTestCase {
    
    func testExample() {
        let text = [
            "* Hello Org",
            "  Testing the org file.",
            ].joined(separator: "\n")
        
        let marker = Marker()
        let result = marker.mark(text)
        switch result {
        case .success(let marks):
            XCTAssertEqual(3, marks.count)
        case .failure(let error):
            XCTFail("\(error)")
        }
    }
    
}
