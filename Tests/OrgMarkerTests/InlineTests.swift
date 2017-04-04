//
//  InlineTests.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 27/03/17.
//
//

import XCTest
@testable import OrgMarker

fileprivate func m1(line: String) throws -> Mark {
  let marker = Marker()
  
  let result = marker.mark(line)
  switch result {
  case .success(let marks):
    XCTAssertEqual(1, marks.count)
    return marks[0]
  case .failure(let error):
    throw error
  }
}

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
      ("_awesome_", "underlined"),
      ("+awesome+", "strikeThrough"),
      ("[[awesome][www.orgmode.org]]", "link"),
    ]
    for (text, name) in syntax {
      let line = "org-mode is \(text). smiley face 😀."
      expect(try m1(line: line),
             to: haveMark(name, to: haveValue(text, on: line)))
    }
  }

}
