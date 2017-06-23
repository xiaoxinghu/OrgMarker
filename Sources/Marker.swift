//
//  Marker.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 13/03/17.
//  Copyright © 2017 Xiaoxing Hu. All rights reserved.
//

import Foundation
import Dispatch

struct Context {
    let text: String
    var grammar: Grammar = Grammar.main()
    
    init(_ _text: String,
         with _grammar: Grammar = Grammar.main()) {
        text = _text
        grammar = _grammar
    }
}

// TODO: Sectionize
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
    public var maxThreads: Int = 4
    
    public init(
        todos _todos: [[String]] = [["TODO"], ["DONE"]]) {
        todos = _todos
    }
    
    public func mark(_ text: String) -> OMResult<[Mark]> {
        return self.mark(text, range: text.startIndex..<text.endIndex)
    }
    
    public func mark(_ text: String, range: Range<String.Index>) -> OMResult<[Mark]> {
        let f = Parser.updateGrammar |> curry(Parser.breakdown)(range) |> Parser.parse
        return f(Context(text))
    }
    
    public func mark(_ text: String, callback: @escaping (OMResult<[Mark]>) -> Void) {
        let ranges: [Range<String.Index>]!
        let context: Context!
        let prepare = _genGrammar |> curry(_breakdown)(text.startIndex..<text.endIndex)
        switch prepare(Context(text)) {
        case let .success(_context, parts):
            ranges = parts
            context = _context
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
        let chunks = _slice(array: ranges, into: maxThreads)
        
        chunks.forEach { chunk in
            queue.async(group: group) {
                completion(result: self._mark(context, ranges: chunk))
            }
        }
        
        group.notify(queue: queue) {
            callback(asyncResult >>- self.sort)
        }
    }
}

extension Marker {
    // MARK: private functions
    
    func _breakdown(_ range: Range<String.Index>, _ context: Context) -> Result<(Context, [Range<String.Index>])> {
        var ranges = [Range<String.Index>]()
        var range = range
        while !range.isEmpty,
            let match = context.text.range(of: "(\(eol))(\\*+)\(space)", options: .regularExpression, range: range) {
                let point = context.text.index(after: match.lowerBound)
                ranges.append(range.lowerBound..<point)
                range = point..<context.text.endIndex
        }
        if !range.isEmpty { ranges.append(range) }
        return .success(context, ranges)
    }
    
    func _genGrammar(_ context: Context) -> Result<Context> {
        
        var range = context.text.startIndex..<context.text.endIndex
        
        // reduce range to pre first headline
        if let (_, match) = context
            .grammar
            .firstMatchingPattern(
                named: "headline", in: context.text, range: range) {
            range = context.text.startIndex..<match.range.lowerBound
        }
        
        // find TODO setting
        var todo = todos.flatMap { $0 }
        if let _todo = context.grammar
            .markup(only: "setting", on: context.text, range: range)
            .first(where: { $0.meta[".key"] == "TODO" }),
            let value = _todo.meta[".value"] {
            todo = value
                .components(separatedBy: .whitespaces)
                .filter { $0 != "|" && !$0.isEmpty }
        }
        
        var context = context
        context.grammar = Grammar.main(todo: todo)
        return .success(context)
    }
    
    func _mark(_ context: Context, range: Range<String.Index>) -> Result<[Mark]> {
        let _mark = curry(tokenize)(context)
            |> curry(matchParagraph)(context.text)
            |> matchList
            |> matchTable
        return _mark(range)
    }
    
    func _mark(_ context: Context, ranges: [Range<String.Index>]) -> Result<[Mark]> {
        func _append(marks1: [Mark], marks2: [Mark]) -> [Mark] {
            return marks1 + marks2
        }
        
        let curriedAppend = curry(_append)
        
        return ranges.reduce(Result.success([Mark]())) { result, range in
            return (curriedAppend <^> result) <*> _mark(context, range: range)
        }
    }
    
    
    func tokenize(_ context: Context, range: Range<String.Index>) -> Result<[Mark]> {
        
        let lexer = Lexer(context.grammar)
        return lexer.tokenize(context.text, range: range)
        
//        do {
//            let marks = try context.grammar.parse(context.text, range: range)
//            return .success(marks)
//        } catch {
//            return .failure(.other(error))
//        }
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
    
    func addSectionInfo(_ marks: [Mark], at index: Int) -> [Mark] {
        var marks = marks
        var headline = marks[index]
        guard let stars = headline.meta[".stars"] else {
            return marks
        }
        
        if let next = marks[index+1..<marks.endIndex]
            .first(where: { $0.name == "headline" && $0.meta[".stars"]!.characters.count <= stars.characters.count }) {
            headline.meta["end"] = next.meta[".text"]
        } else {
            headline.meta["end"] = "EOF"
        }
        marks[index] = headline
        return marks
    }
    
    func updateSectionInfo(_ marks: [Mark]) -> Result<[Mark]> {
        
        let headlines = marks.enumerated().filter { $0.element.name == "headline" }.map { $0.offset }
        
        let marks = headlines.reduce(marks) { result, headline in
            return self.addSectionInfo(result, at: headline)
        }
        
        return .success(marks)
    }
    
    func sort(_ marks: [Mark]) -> Result<[Mark]> {
        let sorted = marks.sorted { (m1, m2) -> Bool in
            return m1.range.lowerBound < m2.range.lowerBound
        }
        return .success(sorted)
    }
}
