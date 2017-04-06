//
//  Marker.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 13/03/17.
//  Copyright © 2017 Xiaoxing Hu. All rights reserved.
//

import Foundation
import Dispatch

public enum Errors: Error {
  case unexpectedToken(String)
  case cannotFindToken(String)
  case illegalNodeForContainer(String)
  case other(String)
}

struct Context {
  let text: String
  var parts: [Range<String.Index>]?
  var grammar: Grammar = Grammar.main()
  
  init(_ _text: String,
       parts _parts: [Range<String.Index>]? = nil,
       with _grammar: Grammar = Grammar.main()) {
    text = _text
    parts = _parts
    grammar = _grammar
  }
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
    let f = breakdown |> genGrammar |> mark
    return f(Context(text))
  }
  
  public func mark(_ text: String, chunkSize: Int = 30, callback: @escaping (Result<[Mark]>) -> Void) {
    let ranges: [Range<String.Index>]!
    let grammar: Grammar!
    let prepare = breakdown |> genGrammar
    switch prepare(Context(text)) {
    case .success(let context):
      ranges = context.parts
      grammar = context.grammar
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
    
    for c in chunks.map({ Context(text, parts: $0, with: grammar) }) {
      queue.async(group: group) {
        completion(result: self.mark(c))
      }
    }

    group.notify(queue: queue) {
      callback(asyncResult >>- self.sort)
    }
  }
}

extension Marker {
  // MARK: private functions
  
  func breakdown(_ context: Context) -> Result<Context> {
    var context = context
    var ranges = [Range<String.Index>]()
    var range = context.text.startIndex..<context.text.endIndex
    while !range.isEmpty,
      let match = context.text.range(of: "(\(eol))(\\*+)\(space)", options: .regularExpression, range: range) {
        let point = context.text.index(after: match.lowerBound)
        ranges.append(range.lowerBound..<point)
        range = point..<context.text.endIndex
    }
    if !range.isEmpty { ranges.append(range) }
    context.parts = ranges
    return .success(context)
  }
  
  func genGrammar(_ context: Context) -> Result<Context> {
    var range: Range<String.Index>!
    if let ranges = context.parts, ranges.count >= 1 {
      range = ranges[0]
    } else {
      range = context.text.startIndex..<context.text.endIndex
    }
    
    var todo = todos.flatMap { $0 }
    let pattern = "\(eol)#\\+TODO:\(space)*(.*)\(eol)"
    var regex: RegularExpression!
    do {
      regex = try RegularExpression(pattern: pattern, options: [])
    } catch {
      return .failure(error)
    }
    if let m = regex.firstMatch(in: context.text, range: range) {
      todo = context.text.substring(with: m.captures[1]!)
        .components(separatedBy: .whitespaces).filter { $0 != "|" && !$0.isEmpty }
    }
    var context = context
    context.grammar = Grammar.main(todo: todo)
    return .success(context)
  }
  
  func mark(_ context: Context, range: Range<String.Index>) -> Result<[Mark]> {
    let _mark =
      curry(tokenize)(context) |> curry(matchParagraph)(context.text) |> matchList |> matchTable
    return _mark(range)
  }
  
  func mark(_ context: Context) -> Result<[Mark]> {
    let ranges = context.parts ?? [context.text.startIndex..<context.text.endIndex]
    return ranges.reduce(.success([Mark]())) { result, range in
      guard case .success(let acc) = result else { return result }
      switch mark(context, range: range) {
      case .success(let marks):
        return .success(acc + marks)
      case .failure(let error):
        return .failure(error)
      }
    }
  }
  
  func tokenize(_ context: Context) -> Result<[Mark]> {
    return tokenize(context, range: context.text.startIndex..<context.text.endIndex)
  }
  
  func tokenize(_ context: Context, range: Range<String.Index>) -> Result<[Mark]> {
    do {
      let marks = try context.grammar.parse(context.text, range: range)
      return .success(marks)
    } catch {
      return .failure(error)
    }
  }
  
  func inlineMarkup(on text: String, range: Range<String.Index>) -> [Mark] {
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
      return m1.range.lowerBound < m2.range.lowerBound
    }
    return .success(sorted)
  }
}
