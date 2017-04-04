//
//  Performance.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 16/09/16.
//  Copyright © 2016 Xiaoxing Hu. All rights reserved.
//

import XCTest
@testable import OrgMarker


class PerformanceTests: XCTestCase {
  
  var content: String = ""
  override func setUp() {
    super.setUp()
    //    let src = "https://raw.githubusercontent.com/xiaoxinghu/dotfiles/master/home.org"
    let src = "https://raw.githubusercontent.com/sachac/.emacs.d/gh-pages/Sacha.org"
    if let url = URL(string: src) {
      do {
        let doc = try String(contentsOf: url)
        let array = [String](repeating: doc, count: 1)
        content = array.joined(separator: "\n\n")
      } catch {
        XCTFail("ERROR: \(error)")
      }
    }
  }
  
  func testMarking() {
    let marker = Marker()
    self.measure {
      _ = marker.tokenize(self.content)
    }
  }
  
  func testParsing() throws {
    let marker = Marker()
    let result = marker.tokenize(content)
    guard case .success(let marks) = result else {
      XCTFail()
      return
    }
    let parse = marker.matchList |> marker.matchTable
    self.measure {
      _ = parse(marks)
    }
  }
  
  /*
   func testSection() throws {
   var marks = try _mark(self.content)
   marks = try analyze(marks)
   self.measure {
   _ = section(marks, on: self.content)
   }
   }
   */
  
  func testSerialization() throws {
    let marker = Marker()
    let result = marker.mark(content)
    guard case .success(let marks) = result else {
      XCTFail("marking failed")
      return
    }
    self.measure {
      _ = marks.map { $0.serialize(on: self.content) }
    }
    
  }
  
  func testTheWholeProcess() throws {
    let marker = Marker()
    self.measure {
      _ = marker.mark(self.content)
    }
  }
  
  func testTheWholeProcessAsync() throws {
    let marker = Marker()
    self.measure {
      let exp = self.expectation(description: "async mark")
      marker.mark(self.content) { _ in exp.fulfill() }
      self.waitForExpectations(timeout: 10, handler: nil)
    }
  }
  
  func testOrder() throws {
    let expectation1 = expectation(description: "expectation1")
    
    let marker = Marker()
    var asyncMarks = [Mark]()
    var syncMarks = [Mark]()
    marker.mark(content) { result in
      switch result {
      case .failure(let error):
        XCTFail("ERROR: \(error)")
      case .success(let marks):
        asyncMarks = marks
        expectation1.fulfill()
      }
    }
    
    switch marker.mark(content) {
    case .success(let marks):
      syncMarks = marks
    case .failure(let error):
      XCTFail("> ERROR: \(error)")
    }
    
    waitForExpectations(timeout: 10, handler: nil)
    XCTAssertEqual(asyncMarks.count, syncMarks.count)
    
    
    print("> got \(asyncMarks.count) marks")
    var first = 0
    for i in 0..<min(asyncMarks.count, syncMarks.count) {
      if asyncMarks[i] == syncMarks[i] { continue }
      if first == 0 { first = i }
      print("> async: \(asyncMarks[i].name), |\(asyncMarks[i].value(on: self.content))|")
      print(">  sync: \(syncMarks[i].name), |\(syncMarks[i].value(on: self.content))|")
      //      XCTAssertEqual(asyncMarks[i], syncMarks[i], "index: \(i)")
    }
    
    print(">>>> first: \(first)")
    
  }
  
  
  static var allTests : [(String, (PerformanceTests) -> () throws -> Void)] {
    return [
      ("testMarking", testMarking),
      //      ("testParsing", testParsing),
      //      ("testSection", testSection),
    ]
  }
  
  
  //  func testTheFileFirst() {
  //    print("File size: \(content.characters.count)")
  //    do {
  //      let parser = OrgParser()
  //      let doc = try parser.parse(content: self.content)
  //      print("\(doc)")
  //    } catch {
  //      print(Thread.callStackSymbols)
  //      XCTFail("ERROR: \(error)")
  //    }
  //  }
}
