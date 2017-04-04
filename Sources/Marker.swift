//
//  Marker.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 13/03/17.
//  Copyright © 2017 Xiaoxing Hu. All rights reserved.
//

import Foundation

public enum Errors: Error {
  case unexpectedToken(String)
  case cannotFindToken(String)
  case illegalNodeForContainer(String)
}


//func section(_ marks: [Mark], on text: String) -> [Mark] {
//
//  func level(of headline: Mark) -> Int {
//    return headline.meta[".stars"]!.characters.count
//  }
//
//
//  let headlines = marks
//    .filter { $0.name == "headline" }
//
//  var sections = [Mark]()
//  var openSections = [Mark]()
//  for headline in headlines {
//    while let last = openSections.last,
//      level(of: headline) >= Int(last.meta[".level"]!)! {
//        var last = openSections.removeLast()
//        last.range = NSMakeRange(last.range.location, headline.range.location - last.range.location)
//        sections.append(last)
//    }
//    var newSec = Mark("section", range: headline.range)
//    newSec.meta[".level"] = "\(level(of: headline))"
//    openSections.append(newSec)
//  }
//
//  while !openSections.isEmpty {
//    var last = openSections.removeLast()
//    last.range = NSMakeRange(last.range.location, text.characters.count - last.range.location)
//    sections.append(last)
//  }
//
//  return marks + sections
//}


//let analyze: (String, [Mark]) -> Result<[Mark]> = matchBlocks |> matchDrawers |> matchParagraph |> matchList |> matchTable
//let mark: (String, NSRange) -> Result<[Mark]> = tokenize |> matchBlocks

//func mark(_ text: String, within range: NSRange) -> Result<[Mark]> {
//  return (tokenize |> curry(analyze)(text))(text, range)
//}


public struct Marker {

  var todos: [[String]]
  let queue = DispatchQueue.global(qos: .userInitiated)
  
  public init(
    todos _todos: [[String]] = [["TODO"], ["DONE"]]) {
    todos = _todos
  }
  
  public func mark(_ text: String) -> Result<[Mark]> {
    let f = breakdown |> curry(genGrammar)(text) |> mark
    return f(text)
  }
  
  public func mark(_ text: String, chunkSize: Int = 30, callback: @escaping (Result<[Mark]>) -> Void) {
    let ranges: [NSRange]!
    let grammar: Grammar!
    let prepare = breakdown |> curry(genGrammar)(text)
    switch prepare(text) {
    case .success(_, let _ranges, let _grammar):
      ranges = _ranges
      grammar = _grammar
    case .failure(let error):
      callback(.failure(error))
      return
    }
    
    var asyncResult: Result<[Mark]> = .success([Mark]())
    let resultQ = DispatchQueue(label: "com.orgmarker.result")

    func completion(result: Result<[Mark]>) {
      resultQ.sync {
        if case .failure = asyncResult { return }
        guard case .success(let all) = asyncResult else { return }
        switch result {
        case .success(let chunk):
          asyncResult = .success(all + chunk)
        case .failure:
          asyncResult = result
        }
      }
    }

    let group = DispatchGroup()
    let chunks = stride(from: 0, to: ranges.count, by: chunkSize).map {
      Array(ranges[$0..<min($0 + chunkSize, ranges.count)])
    }
    for chunk in chunks {
      queue.async(group: group) {
        completion(result: self.mark(text, ranges: chunk, with: grammar))
      }
    }

    group.notify(queue: queue) {
      callback(asyncResult >>- self.sort)
    }
  }
}

extension Marker {
  // MARK: private functions
  
  fileprivate func breakdown(_ text: String) -> Result<[NSRange]> {
    let pattern = "(\(eol))(\\*+)\(space)"
    let regex: RegularExpression!
    do {
      regex = try RegularExpression(pattern: pattern, options: [])
    } catch {
      return .failure(error)
    }
    let matches = regex.matches(in: text, options: [], range: NSMakeRange(0, text.characters.count))
    var loc = 0
    var ranges = [NSRange]()
    for m in matches {
      let stars = m.rangeAt(1)
      let newLoc = stars.location + 1
      let range = NSMakeRange(loc, newLoc - loc)
      ranges.append(range)
      loc = newLoc
    }
    if loc < text.characters.count {
      ranges.append(NSMakeRange(loc, text.characters.count - loc))
    }
    return .success(ranges)
  }
  
  func genGrammar(_ text: String, ranges: [NSRange]) -> Result<(String, [NSRange], Grammar)> {
    var todo = ["TODO", "DONE"]
    let pattern = "\(eol)#\\+TODO:\(space)*(.*)\(eol)"
    var regex: RegularExpression!
    do {
      regex = try RegularExpression(pattern: pattern, options: [])
    } catch {
      return .failure(error)
    }
    if let m = regex.firstMatch(in: text, options: [], range: ranges[0]) {
      todo = (text as NSString).substring(with: m.rangeAt(1))
        .components(separatedBy: .whitespaces).filter { $0 != "|" && !$0.isEmpty }
    }
    
    return .success(text, ranges, Grammar.main(todo: todo))
  }
  
  func mark(_ text: String, range: NSRange, with grammar: Grammar) -> Result<[Mark]> {
    let _mark =
      curry(tokenize)(text)(grammar) |> curry(matchParagraph)(text) |> matchList |> matchTable
    return _mark(range)
  }
  
  func mark(_ text: String, ranges: [NSRange], with grammar: Grammar) -> Result<[Mark]> {
    return ranges.reduce(.success([Mark]())) { result, range in
      guard case .success(let acc) = result else { return result }
      switch mark(text, range: range, with: grammar) {
      case .success(let marks):
        return .success(acc + marks)
      case .failure(let error):
        return .failure(error)
      }
    }
  }
  
  func tokenize(_ text: String, with grammar: Grammar = Grammar.main(), range: NSRange? = nil) -> Result<[Mark]> {
    let range = range ?? NSMakeRange(0, text.characters.count)
    do {
      let marks = try grammar.parse(text, range: range)
      return .success(marks)
    } catch {
      return .failure(error)
    }
  }
  
  func inlineMarkup(on text: String, range: NSRange) -> [Mark] {
    return Grammar.inline.markup(on: text, range: range)
  }
  
  func matchParagraph(on text: String, _ marks: [Mark]) -> Result<[Mark]> {
    let combined = _combine(marks, name: "paragraph", processContent: curry(inlineMarkup)(text)) { $0.name == "line" }
    return .success(combined)
  }
  
  func matchList(_ marks: [Mark]) -> Result<[Mark]> {
    return .success(_group(marks, name: "list") { $0.name == "list.item" })
  }
  
  func matchTable(_ marks: [Mark]) -> Result<[Mark]> {
    return .success(_group(marks, name: "table") { $0.name.hasPrefix("table.") })
  }
  
  func sort(_ marks: [Mark]) -> Result<[Mark]> {
    let sorted = marks.sorted { (m1, m2) -> Bool in
      return m1.range.location < m2.range.location
    }
    return .success(sorted)
  }
}
