//
//  MarkerTests.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 8/12/16.
//  Copyright © 2016 Xiaoxing Hu. All rights reserved.
//

import XCTest
@testable import OrgMarker

class MarkerTests: XCTestCase {

  var text: String!
  var lines: [String]!
  override func setUp() {
    lines = [
      /* 00 */ "#+TITLE: Org Mode Syntax",
      /* 01 */ "#+TODO: TODO NEXT | DONE",
      /* 02 */ "",
      /* 03 */ "* NEXT Section One         :tag1:tag2:",
      /* 04 */ "  DEADLINE: <2017-02-28 Tue>",
      /* 05 */ "  :PROPERTIES:",
      /* 06 */ "  :CATEGORY: nice",
      /* 07 */ "  :END:",
      /* 08 */ "",
      /* 09 */ "  Fist line of a *paragraph*.",
      /* 10 */ "  [[org-mode][www.org-mode.org]] is awesome.",
      /* 11 */ "-----",
      /* 12 */ "| Name         | Species    | Gender | Role         |",
      /* 13 */ "|--------------+------------+--------+--------------|",
      /* 14 */ "| Bruce Wayne  | Human      | M      | Batman       |",
      /* 15 */ "| Clark Kent   | Kryptonian | M      | Superman     |",
      /* 16 */ "| Diana Prince | Amazonian  | F      | Wonder Woman |",
      /* 17 */ "-----",
      /* 18 */ "- list item one",
      /* 19 */ "2. [ ] list item two",
      /* 20 */ "  1) [X] list item two.one",
      /* 21 */ "-----",
      /* 22 */ "#+BEGIN_SRC swift",
      /* 23 */ "let stuff = \"org-mode\"",
      /* 24 */ "print(\"\\(stuff) is awesome.\")",
      /* 25 */ "#+end_src",
      /* 26 */ "-----",
      /* 27 */ "# This is a comment.",
      /* 28 */ "* [#A] Section Two",
      /* 29 */ "** Section Two.One",
      /* 30 */ "-----",
      /* 31 */ "[fn:1] footnote one.",
    ]

    text = lines.joined(separator: "\n")

  }

  func eval(_ marks: [Mark], at cursor: Int,
         file: StaticString = #file, line: UInt = #line,
         that: (Mark) -> Void) -> Int {
    if marks.count <= cursor {
      XCTFail("mark is nil", file: file, line: line)
      return cursor + 1

    }
    that(marks[cursor])
    return cursor + 1
  }

  func testMarking() throws {

    let marker = Marker()
    guard case .success(_, _, let grammar) = marker.genGrammar(text, ranges: [NSMakeRange(0, text.characters.count)]) else {
      XCTFail()
      return
    }
    let result = marker.tokenize(text, with: grammar)
    guard case .success(let marks) = result else {
      XCTFail()
      return
    }


    var cursor = 0

    func test(file: StaticString = #file, line: UInt = #line,
              evaluate: (Mark) -> Void) {
      cursor = eval(marks, at: cursor,
                    file: file, line: line,
                    that: evaluate)
    }

    test { mark in
      expect(mark, to: beNamed("setting"))
      expect(mark, to: haveMark(to: beNamed("setting.key")))
      expect(mark, to: haveMark("setting.key", to: haveValue("TITLE", on: text)))
      expect(mark, to: haveMark("setting.value", to: haveValue("Org Mode Syntax", on: text)))
      expect(mark, to: haveMeta(key: ".key", value: "TITLE"))
      expect(mark, to: haveMeta(key: ".value", value: "Org Mode Syntax"))
    }
    test { mark in
      expect(mark, to: beNamed("setting"))
      expect(mark, to: haveMark("setting.key", to: haveValue("TODO", on: text)))
      expect(mark, to: haveMark("setting.value", to: haveValue("TODO NEXT | DONE", on: text)))
      expect(mark, to: haveMeta(key: ".key", value: "TODO"))
      expect(mark, to: haveMeta(key: ".value", value: "TODO NEXT | DONE"))
    }

    test { expect($0, to: beNamed("blank")) }

    test { mark in
      expect(mark, to: beNamed("headline"))
      expect(mark, to: haveMark("headline.stars", to: haveValue("*", on: text)))
      expect(mark, to: haveMark("headline.keyword", to: haveValue("NEXT", on: text)))
      expect(mark, to: haveMark("headline.text", to: haveValue("Section One", on: text)))
      expect(mark, to: haveMark("headline.tags", to: haveValue(":tag1:tag2:", on: text)))
    }

    test { mark in
      expect(mark, to: beNamed("planning"))
      expect(mark, to: haveMark("planning.keyword", to: haveValue("DEADLINE", on: text)))
      expect(mark, to: haveMark("planning.timestamp", to: haveValue("<2017-02-28 Tue>", on: text)))

    }

    test { mark in
      expect(mark, to: beNamed("drawer"))
      expect(mark, to: haveMark("drawer.name", to: haveValue("PROPERTIES", on: text)))
      expect(mark, to: haveMark("drawer.content", to: haveValue("\(lines[6])\n", on: text)))
    }

    test { expect($0, to: beNamed("blank")) }
    test { expect($0, to: beNamed("line")) }
    test { expect($0, to: beNamed("line")) }
    test { expect($0, to: beNamed("horizontalRule")) }

    // table
    test { expect($0, to: beNamed("table.row")) }
    test { expect($0, to: beNamed("table.separator")) }
    test { expect($0, to: beNamed("table.row")) }
    test { expect($0, to: beNamed("table.row")) }
    test { expect($0, to: beNamed("table.row")) }
    test { expect($0, to: beNamed("horizontalRule")) }

    // list
    test { mark in
      expect(mark, to: beNamed("list.item"))
      expect(mark, to: haveMark("list.item.bullet", to: haveValue("-", on: text)))
      expect(mark, to: haveMark("list.item.text", to: haveValue("list item one", on: text)))
    }
    test { mark in
      expect(mark, to: beNamed("list.item"))
      expect(mark, to: haveMark("list.item.bullet", to: haveValue("2.", on: text)))
      expect(mark, to: haveMark("list.item.checker", to: haveValue("[ ]", on: text)))
      expect(mark, to: haveMark("list.item.text", to: haveValue("list item two", on: text)))
    }
    test { mark in
      expect(mark, to: beNamed("list.item"))
      expect(mark, to: haveMark("list.item.indent", to: haveValue("  ", on: text)))
      expect(mark, to: haveMark("list.item.bullet", to: haveValue("1)", on: text)))
      expect(mark, to: haveMark("list.item.checker", to: haveValue("[X]", on: text)))
      expect(mark, to: haveMark("list.item.text", to: haveValue("list item two.one", on: text)))
    }

    test { expect($0, to: beNamed("horizontalRule")) }

    // block
    test { mark in
      expect(mark, to: beNamed("block"))
      expect(mark, to: haveMark("block.type", to: haveValue("SRC", on: text)))
      expect(mark, to: haveMark("block.params", to: haveValue("swift", on: text)))
    }
    test { expect($0, to: beNamed("horizontalRule")) }

    // comment
    test { expect($0, to: beNamed("comment")) }

    // section
    test { mark in
      expect(mark, to: beNamed("headline"))
      expect(mark, to: haveMark("headline.stars", to: haveValue("*", on: text)))
      expect(mark, to: haveMark("headline.priority", to: haveValue("A", on: text)))
      expect(mark, to: haveMark("headline.text", to: haveValue("Section Two", on: text)))
    }
    test { mark in
      expect(mark, to: beNamed("headline"))
      expect(mark, to: haveMark("headline.stars", to: haveValue("**", on: text)))
      expect(mark, to: haveMark("headline.text", to: haveValue("Section Two.One", on: text)))
    }
    test { expect($0, to: beNamed("horizontalRule")) }

    // footnote
    test { mark in
      expect(mark, to: beNamed("footnote"))
      expect(mark, to: haveMark("footnote.label", to: haveValue("1", on: text)))
      expect(mark, to: haveMark("footnote.content", to: haveValue("footnote one.", on: text)))
    }

  }

  func testStructualGrouping() throws {

    let exp = expectation(description: "marker")
    let marker = Marker()
    var marks = [Mark]()
    marker.mark(text) { result in
      switch result {
      case .failure(let error):
        XCTFail(">> ERROR: \(error)")
      case .success(let _marks):
        marks = _marks
        exp.fulfill()
      }
    }
    waitForExpectations(timeout: 10, handler: nil)

    var cursor = 0

    func test(file: StaticString = #file, line: UInt = #line,
              evaluate: (Mark) -> Void) {
      cursor = eval(marks, at: cursor,
                    file: file, line: line,
                    that: evaluate)
    }

    test { mark in
      expect(mark, to: beNamed("setting"))
      expect(mark, to: haveMark(to: beNamed("setting.key")))
      expect(mark, to: haveMark("setting.key", to: haveValue("TITLE", on: text)))
      expect(mark, to: haveMark("setting.value", to: haveValue("Org Mode Syntax", on: text)))
      expect(mark, to: haveMeta(key: ".key", value: "TITLE"))
      expect(mark, to: haveMeta(key: ".value", value: "Org Mode Syntax"))
    }
    test { mark in
      expect(mark, to: beNamed("setting"))
      expect(mark, to: haveMark("setting.key", to: haveValue("TODO", on: text)))
      expect(mark, to: haveMark("setting.value", to: haveValue("TODO NEXT | DONE", on: text)))
      expect(mark, to: haveMeta(key: ".key", value: "TODO"))
      expect(mark, to: haveMeta(key: ".value", value: "TODO NEXT | DONE"))
    }

    test { expect($0, to: beNamed("blank")) }

    test { mark in
      expect(mark, to: beNamed("headline"))
      expect(mark, to: haveMark("headline.stars", to: haveValue("*", on: text)))
      expect(mark, to: haveMark("headline.keyword", to: haveValue("NEXT", on: text)))
      expect(mark, to: haveMark("headline.text", to: haveValue("Section One", on: text)))
      expect(mark, to: haveMark("headline.tags", to: haveValue(":tag1:tag2:", on: text)))
    }

    test { mark in
      expect(mark, to: beNamed("planning"))
      expect(mark, to: haveMark("planning.keyword", to: haveValue("DEADLINE", on: text)))
      expect(mark, to: haveMark("planning.timestamp", to: haveValue("<2017-02-28 Tue>", on: text)))

    }

    test { mark in
      expect(mark, to: beNamed("drawer"))
      expect(mark, to: haveMark("drawer.name", to: haveValue("PROPERTIES", on: text)))
      expect(mark, to: haveMark("drawer.content", to: haveValue("\(lines[6])\n", on: text)))
    }

    test { expect($0, to: beNamed("blank")) }

    // paragraph
    test { mark in
      expect(mark, to: beNamed("paragraph"))
      expect(mark, to: haveMark("bold", to: haveValue("*paragraph*", on: text)))
      expect(mark, to: haveMark("link", to: beNamed("link")))
    }
    test { expect($0, to: beNamed("horizontalRule")) }

    // table

    test { mark in
      expect(mark, to: beNamed("table"))
      expect(mark, to: haveMark("table.row", to: haveValue("\(lines[12])\n", on: text)))
      expect(mark, to: haveMark("table.separator", to: haveValue("\(lines[13])\n", on: text)))
      expect(mark, to: haveMark("table.row", to: haveValue("\(lines[14])\n", on: text)))
      expect(mark, to: haveMark("table.row", to: haveValue("\(lines[15])\n", on: text)))
      expect(mark, to: haveMark("table.row", to: haveValue("\(lines[16])\n", on: text)))
    }
    test { expect($0, to: beNamed("horizontalRule")) }

    // list
    test { mark in
      expect(mark, to: beNamed("list"))
      expect(mark, to: haveMark("list.item", to: haveValue("\(lines[18])\n", on: text)))
      expect(mark, to: haveMark("list.item", to: haveValue("\(lines[19])\n", on: text)))
      expect(mark, to: haveMark("list.item", to: haveValue("\(lines[20])\n", on: text)))
    }

    test { expect($0, to: beNamed("horizontalRule")) }

    // block
    test { mark in
      expect(mark, to: beNamed("block"))
      expect(mark, to: haveMark("block.type", to: haveValue("SRC", on: text)))
      expect(mark, to: haveMark("block.params", to: haveValue("swift", on: text)))
    }
    test { expect($0, to: beNamed("horizontalRule")) }

    // comment
    test { expect($0, to: beNamed("comment")) }

    // section
    test { mark in
      expect(mark, to: beNamed("headline"))
      expect(mark, to: haveMark("headline.stars", to: haveValue("*", on: text)))
      expect(mark, to: haveMark("headline.priority", to: haveValue("A", on: text)))
      expect(mark, to: haveMark("headline.text", to: haveValue("Section Two", on: text)))
    }
    test { mark in
      expect(mark, to: beNamed("headline"))
      expect(mark, to: haveMark("headline.stars", to: haveValue("**", on: text)))
      expect(mark, to: haveMark("headline.text", to: haveValue("Section Two.One", on: text)))
    }
    test { expect($0, to: beNamed("horizontalRule")) }

    // footnote
    test { mark in
      expect(mark, to: beNamed("footnote"))
      expect(mark, to: haveMark("footnote.label", to: haveValue("1", on: text)))
      expect(mark, to: haveMark("footnote.content", to: haveValue("footnote one.", on: text)))
    }

  }

  func testSection() throws {
    let exp = expectation(description: "marker")
    let marker = Marker()
    var marks = [Mark]()
    marker.mark(text) { result in
      switch result {
      case .failure(let error):
        XCTFail(">> ERROR: \(error)")
      case .success(let _marks):
        marks = _marks
        exp.fulfill()
      }
    }
    waitForExpectations(timeout: 10, handler: nil)


//    let dict = marks.map { $0.serialize(on: text) }
//    let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
//    let json = String(data: data, encoding: .utf8)!
//    print(">>>>>>>>>>>>>>>>>>>>>")
//    print("\(json)")

    for section in marks.filter({ $0.name == "section" }) {
      print(">>>>>>>>>>>>>>>>>>>>>")
      print("\(section.value(on: text))")
      print("<<<<<<<<<<<<<<<<<<<<<")
    }
  }

  func testPOC() throws {
  }

  static var allTests : [(String, (MarkerTests) -> () throws -> Void)] {
    return [
      ("testMarking", testMarking),
//      ("testStructualGrouping", testStructualGrouping),
//      ("testSection", testSection),
    ]
  }

}
