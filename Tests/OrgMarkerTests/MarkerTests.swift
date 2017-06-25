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
            "#+TITLE: Org Mode Syntax",                              /* 00 */
            "#+TODO: TODO NEXT | DONE",                              /* 01 */
            "",                                                      /* 02 */
            "* NEXT Section One         :tag1:tag2:",                /* 03 */
            "  DEADLINE: <2017-02-28 Tue>",                          /* 04 */
            "  :PROPERTIES:",                                        /* 05 */
            "  :CATEGORY: nice",                                     /* 06 */
            "  :END:",                                               /* 07 */
            "",                                                      /* 08 */
            "  Fist line of a *paragraph*.",                         /* 09 */
            "  [[org-mode][www.org-mode.org]] is awesome.",          /* 10 */
            "-----",                                                 /* 11 */
            "| Name         | Species    | Gender | Role         |", /* 12 */
            "|--------------+------------+--------+--------------|", /* 13 */
            "| Bruce Wayne  | Human      | M      | Batman       |", /* 14 */
            "| Clark Kent   | Kryptonian | M      | Superman     |", /* 15 */
            "| Diana Prince | Amazonian  | F      | Wonder Woman |", /* 16 */
            "-----",                                                 /* 17 */
            "- list item one",                                       /* 18 */
            "2. [ ] list item two",                                  /* 19 */
            "  1) [X] list item two.one",                            /* 20 */
            "-----",                                                 /* 21 */
            "#+BEGIN_SRC swift",                                     /* 22 */
            "let stuff = \"org-mode\"",                              /* 23 */
            "print(\"\\(stuff) is awesome.\")",                      /* 24 */
            "#+end_src",                                             /* 25 */
            "-----",                                                 /* 26 */
            "# This is a comment.",                                  /* 27 */
            "* [#A] Section Two",                                    /* 28 */
            "** Section Two.One",                                    /* 29 */
            "-----",                                                 /* 30 */
            "[fn:1] footnote one.",                                  /* 31 */
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
        let adapt: (Context) -> Result<(Context, Range<String.Index>)> = {
            return .success(($0, $0.text.startIndex..<$0.text.endIndex))
        }
        
        let f = Parser.updateGrammar |> adapt |> tokenize
        //    guard case .success(_, _, let grammar) = marker.genGrammar(Context(text)) else {
        //      XCTFail()
        //      return
        //    }
        let result = f(Context(text))
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
        
        let marker = Marker()
        let result = marker.mark(text)
        guard case .success(let marks) = result else {
            XCTFail("Failed to mark text")
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
        // TODO: implement test
    }
    
    func testSerialization() throws {
        
        let dict = mark(text).map { $0.serialize(on: text) }
        let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
        let json = String(data: data, encoding: .utf8)!
        print(">>>>>>>>>>>>>>>>>>>>>")
        print("\(json)")
        print(">>>>>>>>>>>>>>>>>>>>>")
        
    }
    
    func testPartialMarking() {
        let marker = Marker()
        let result = marker.mark(text, range: text.range(of: "* NEXT Section One         :tag1:tag2:\n")!)
        guard case .success(let marks) = result else {
            XCTFail("failed to mark")
            return
        }
        XCTAssertEqual(1, marks.count)
        let mark = marks[0]
        expect(mark, to: beNamed("headline"))
        expect(mark, to: haveMark("headline.stars", to: haveValue("*", on: text)))
        expect(mark, to: haveMark("headline.keyword", to: haveValue("NEXT", on: text)))
        expect(mark, to: haveMark("headline.text", to: haveValue("Section One", on: text)))
        expect(mark, to: haveMark("headline.tags", to: haveValue(":tag1:tag2:", on: text)))

    }
    
    static var allTests : [(String, (MarkerTests) -> () throws -> Void)] {
        return [
            ("testMarking", testMarking),
            ("testPartialMarking", testPartialMarking),
            //      ("testStructualGrouping", testStructualGrouping),
            //      ("testSection", testSection),
        ]
    }
    
}
