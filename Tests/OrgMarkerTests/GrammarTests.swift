//
//  GrammarTests.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 15/03/17.
//
//

import XCTest
@testable import OrgMarker

class GrammarTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    
    func testBlank() {
        EvalOneliner("\n", named: "blank")
        EvalOneliner(" ", named: "blank")
        EvalOneliner("\t", named: "blank")
        EvalOneliner("  \t ", named: "blank")
    }
    
    func testSetting() {
        let name = "setting"
        
        func evalSetting(_ string: String, key: String, value: String?,
                         file: StaticString = #file, line: UInt = #line) {
            EvalOneliner(string, named: "setting", file: file, line: line) { mark, text in
                
                eval(mark[".key"], value: key, on: text, file: file, line: line)
                if let value = value {
                    XCTAssertEqual(2, mark.marks.count, file: file, line: line)
                    eval(mark[".value"], value: value, on: text, file: file, line: line)
                } else {
                    XCTAssertEqual(1, mark.marks.count, file: file, line: line)
                }
            }
            
        }
        
        evalSetting("#+options: toc:nil😀", key: "options", value: "toc:nil😀")
        evalSetting("#+options:    toc:nil", key: "options", value: "toc:nil")
        evalSetting("#+TITLE: hello world", key: "TITLE", value: "hello world")
        evalSetting("#+TITLE: ", key: "TITLE", value: nil)
        evalSetting("#+TITLE:", key: "TITLE", value: nil)
    }
    
    func testHeadline() {
        
        EvalOneliner("* Level One", named: "headline") { mark, text in
            XCTAssertEqual(2, mark.marks.count)
            expect(mark, to: haveMark("headline.stars", to: haveValue("*", on: text)))
            expect(mark, to: haveMark("headline.text", to: haveValue("Level One", on: text)))
        }
        
        EvalOneliner("** Level Two", named: "headline") { mark, text in
            XCTAssertEqual(2, mark.marks.count)
            expect(mark, to: haveMark("headline.stars", to: haveValue("**", on: text)))
            expect(mark, to: haveMark("headline.text", to: haveValue("Level Two", on: text)))
        }
        
        EvalOneliner("* TODO Level One with todo", named: "headline") { mark, text in
            XCTAssertEqual(3, mark.marks.count)
            expect(mark, to: haveMark("headline.stars", to: haveValue("*", on: text)))
            expect(mark, to: haveMark("headline.keyword", to: haveValue("TODO", on: text)))
            expect(mark, to: haveMark("headline.text", to: haveValue("Level One with todo", on: text)))
        }
        
        EvalOneliner("* ", named: "headline") { mark, text in
            XCTAssertEqual(1, mark.marks.count)
            expect(mark, to: haveMark("headline.stars", to: haveValue("*", on: text)))
        }
        
        EvalOneliner("*", named: "line")
        EvalOneliner(" * ", named: "list.item")
        
    }
    
    // TODO implement me
    func testPlanning() {
        let date = "2017-01-09"
        let time = "18:00"
        let day = "Tue"
        
        let _timestamp = "\(date) \(day) \(time)"
        
        //    let theDate = quickDate(date: date, time: time)
        func evalPlanning(_ string: String, keyword: String, timestamp: String,
                          file: StaticString = #file, line: UInt = #line) {
            EvalOneliner(string, named: "planning", file: file, line: line) { mark, text in
                eval(mark[".keyword"], value: keyword, on: string, file: file, line: line)
                eval(mark[".timestamp"], value: timestamp, on: string, file: file, line: line)
            }
        }
        
        evalPlanning("CLOSED: [\(date) \(day) \(time)]", keyword: "CLOSED", timestamp: "[\(date) \(day) \(time)]")
        evalPlanning("SCHEDULED: <\(date) \(day) \(time) +2w>", // with repeater
            keyword: "SCHEDULED",
            timestamp: "<\(date) \(day) \(time) +2w>")
        evalPlanning("SCHEDULED:   <\(date) \(day) \(time) +2w>", // with extra spaces before timestamp
            keyword: "SCHEDULED",
            timestamp: "<\(date) \(day) \(time) +2w>")
        evalPlanning("   SCHEDULED: <\(date) \(day) \(time) +2w>", // with leading space
            keyword: "SCHEDULED",
            timestamp: "<\(date) \(day) \(time) +2w>")
        evalPlanning("SCHEDULED: <\(date) \(day) \(time) +2w>     ", // with trailing space
            keyword: "SCHEDULED",
            timestamp: "<\(date) \(day) \(time) +2w>")
        evalPlanning("    SCHEDULED: <\(date) \(day) \(time) +2w>     ", // with leading & trailing space
            keyword: "SCHEDULED",
            timestamp: "<\(date) \(day) \(time) +2w>")
        
        // illegal ones are considered normal line
        EvalOneliner("closed: <\(date) \(day) \(time)>", // case sensitive
            named: "line")
        
        EvalOneliner("OPEN: <\(date) \(day) \(time)>", // illegal keyword
            named: "line")
    }
    
    
    // the blocks are all lines now, since they need to pair together to be reconginized
    
    func testBlockBegin() {
        
        EvalOneliner("#+begin_src", named: "line")
        EvalOneliner("#+begin_src java", named: "line")
        EvalOneliner("  #+begin_src yaml exports: results :results value html", named: "line")
        //    EvalOneliner("#+begin_src", named: "block.begin") { mark, text in
        //      XCTAssertEqual(1, mark.marks.count)
        //      eval(mark[".type"], value: "src", on: text)
        //    }
        //    EvalOneliner("#+begin_src java", named: "block.begin") { mark, text in
        //      XCTAssertEqual(2, mark.marks.count)
        //      eval(mark[".type"], value: "src", on: text)
        //      eval(mark[".params"], value: "java", on: text)
        //    }
        //    EvalOneliner("  #+begin_src yaml exports: results :results value html", named: "block.begin") { mark, text in
        //      XCTAssertEqual(2, mark.marks.count)
        //      eval(mark[".type"], value: "src", on: text)
        //      eval(mark[".params"], value: "yaml exports: results :results value html", on: text)
        //    }
    }
    
    func testBlockEnd() {
        EvalOneliner("#+END_SRC", named: "line")
        EvalOneliner("  #+end_src", named: "line")
        //    EvalOneliner("#+END_SRC", named: "block.end") { mark, text in
        //      XCTAssertEqual(1, mark.marks.count)
        //      eval(mark[".type"], value: "SRC", on: text)
        //    }
        //    EvalOneliner("  #+end_src", named: "block.end") { mark, text in
        //      XCTAssertEqual(1, mark.marks.count)
        //      eval(mark[".type"], value: "src", on: text)
        //    }
    }
    
    func testComment() {
        EvalOneliner("# a line of comment", named: "comment")
        EvalOneliner("#    a line of comment", named: "comment")
        EvalOneliner("#not comment", named: "line")
    }
    
    func testHorizontalRule() {
        EvalOneliner("-----", named: "horizontalRule")
        EvalOneliner("----------", named: "horizontalRule")
        EvalOneliner("  -----", named: "horizontalRule")
    }
    
    func testListItem() {
        
        func evalListItem(_ string: String,
                          indent: String? = nil,
                          bullet: String,
                          text: String,
                          checker: String? = nil,
                          file: StaticString = #file, line: UInt = #line) {
            EvalOneliner(string, named: "list.item", file: file, line: line) { mark, string in
                var count = 2
                eval(mark[".bullet"], value: bullet, on: string, file: file, line: line)
                eval(mark[".text"], value: text, on: string, file: file, line: line)
                if let indent = indent {
                    count += 1
                    eval(mark[".indent"], value: indent, on: string, file: file, line: line)
                    
                }
                if let checker = checker {
                    count += 1
                    eval(mark[".checker"], value: checker, on: string, file: file, line: line)
                }
                XCTAssertEqual(count, mark.marks.count, file: file, line: line)
            }
        }
        
        evalListItem("- list item", indent: nil, bullet: "-", text: "list item")
        evalListItem(" + list item", indent: " ", bullet: "+", text: "list item")
        evalListItem("  * list item", indent: "  ", bullet: "*", text: "list item")
        evalListItem("1. ordered list item", indent: nil, bullet: "1.", text: "ordered list item")
        evalListItem("  200) ordered list item", indent: "  ", bullet: "200)", text: "ordered list item")
        // checkboxes
        evalListItem("- [ ] checkbox", bullet: "-", text: "checkbox", checker: "[ ]")
        evalListItem("- [-] checkbox", bullet: "-", text: "checkbox", checker: "[-]")
        evalListItem("- [X] checkbox", bullet: "-", text: "checkbox", checker: "[X]")
        // illegal checkboxes
        evalListItem("- [] checkbox", bullet: "-", text: "[] checkbox")
        evalListItem("- [X]checkbox", bullet: "-", text: "[X]checkbox")
        evalListItem("- [Y] checkbox", bullet: "-", text: "[Y] checkbox")
        EvalOneliner("-[X] checkbox", named: "line")
    }
    
    // the drawer are all lines now, since they need to pair together to be reconginized
    func testDrawer() {
        EvalOneliner(":PROPERTY:", named: "line")
        EvalOneliner("  :properties:", named: "line")
        EvalOneliner("  :properties:     ", named: "line")
        //    EvalOneliner(":PROPERTY:", named: "drawer.begin") { mark, text in
        //      XCTAssertEqual(1, mark.marks.count)
        //      eval(mark[".name"], value: "PROPERTY", on: text)
        //    }
        //    EvalOneliner("  :properties:", named: "drawer.begin") { mark, text in
        //      XCTAssertEqual(1, mark.marks.count)
        //      eval(mark[".name"], value: "properties", on: text)
        //    }
        //    EvalOneliner("  :properties:     ", named: "drawer.begin") { mark, text in
        //      XCTAssertEqual(1, mark.marks.count)
        //      eval(mark[".name"], value: "properties", on: text)
        //    }
        
        EvalOneliner(":END:", named: "line")
        EvalOneliner("  :end:", named: "line")
        EvalOneliner("  :end:   ", named: "line")
    }
    
    func testTable() {
        // valid table rows
        EvalOneliner("| hello | world | y'all |", named: "table.row")
        EvalOneliner("   | hello | world | y'all |", named: "table.row")
        EvalOneliner("|     hello | world       |y'all |", named: "table.row")
        EvalOneliner("| hello | world | y'all", named: "table.row")
        EvalOneliner("|+", named: "table.row")
        
        // invalid table rows
        EvalOneliner(" hello | world | y'all |", named: "line")
        
        // horizontal separator
        EvalOneliner("|----+---+----|", named: "table.separator")
        EvalOneliner("|---=+---+----|", named: "table.separator")
        EvalOneliner("   |----+---+----|", named: "table.separator")
        EvalOneliner("|----+---+---", named: "table.separator")
        EvalOneliner("|-", named: "table.separator")
        EvalOneliner("|---", named: "table.separator")
        
        // invalud horizontal separator
        EvalOneliner("----+---+----|", named: "line")
    }
    
    func testFootnote() {
        func evalFootnote(_ string: String, label: String, content: String? = nil,
                          file: StaticString = #file, line: UInt = #line) {
            EvalOneliner(string, named: "footnote") { mark, text in
                eval(mark[".label"], value: label, on: string, file: file, line: line)
                if let content = content {
                    eval(mark[".content"], value: content, on: string, file: file, line: line)
                }
            }
        }
        
        evalFootnote("[fn:1] the footnote", label: "1", content: "the footnote")
        evalFootnote("[fn:1]  \t the footnote", label: "1", content: "the footnote")
        evalFootnote("[fn:999] the footnote", label: "999", content: "the footnote")
        evalFootnote("[fn:23]", label: "23")
        evalFootnote("[fn:23]  ", label: "23")
        EvalOneliner(" [fn:1] the footnote", named: "line")
        EvalOneliner("a[fn:1] the footnote", named: "line")
        EvalOneliner("[fn:1]the footnote", named: "line")
    }
    
    
    static var allTests : [(String, (GrammarTests) -> () throws -> Void)] {
        return [
            ("testBlank", testBlank),
        ]
    }
}

fileprivate func EvalOneliner(_ text: String,
                              named name: String,
                              file: StaticString = #file, line: UInt = #line,
                              and: (Mark, String) -> Void = { _ in }) {
    do {
        let result = Marker().tokenize(Context(text))
        switch result {
        case .success(let marks):
            XCTAssertEqual(1, marks.count, file: file, line: line)
            let mark = marks[0]
            XCTAssertEqual(name, mark.name, file: file, line: line)
            and(mark, text)
        case .failure(let err):
            throw err
        }
    } catch {
        XCTFail(">ERROR: \(error).", file: file, line: line)
    }
}

fileprivate func eval(_ mark: Mark?, value: String, on text: String,
                      file: StaticString = #file, line: UInt = #line) {
    if let mark = mark {
        XCTAssertEqual(value, mark.value(on: text), file: file, line: line)
    } else {
        XCTFail("The mark doesn't exist.", file: file, line: line)
    }
}
