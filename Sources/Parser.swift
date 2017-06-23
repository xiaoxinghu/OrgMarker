//
//  Parser.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 24/06/17.
//
//

import Foundation

class Parser {
}

extension Parser {
    
    static func updateGrammar(context: Context) -> OMResult<Context> {
        let text = context.text
        let grammar = context.grammar
        
        var range = text.startIndex..<text.endIndex
        
        // reduce range to pre first headline
        if let (_, match) = grammar
            .firstMatchingPattern(
                named: "headline", in: text, range: range) {
            range = text.startIndex..<match.range.lowerBound
        }
        
        // find TODO setting
        
        var updatedGrammar: Grammar?
        if let _todo = grammar
            .markup(only: "setting", on: text, range: range)
            .first(where: { $0.meta[".key"] == "TODO" }),
            let value = _todo.meta[".value"] {
            let todo = value
                .components(separatedBy: .whitespaces)
                .filter { $0 != "|" && !$0.isEmpty }
            updatedGrammar = Grammar.main(todo: todo)
        }
        
        
        return .success(updatedGrammar != nil ? Context(text, with: updatedGrammar!) : context)
    }
    
    static func breakdown(_ range: Range<String.Index>, _ context: Context) -> Result<(Context, [Range<String.Index>])> {
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
    
    static func parse(_ context: Context, range: Range<String.Index>) -> OMResult<[Mark]> {
        let lexer = Lexer(context.grammar)
        
        let _mark = curry(lexer.tokenize)(context.text)
            |> curry(matchParagraph)(context.text)
            |> matchList
            |> matchTable
        return _mark(range)
    }

    static func parse(_ context: Context, ranges: [Range<String.Index>]) -> OMResult<[Mark]> {
        func _append(marks1: [Mark], marks2: [Mark]) -> [Mark] {
            return marks1 + marks2
        }
        
        let curriedAppend = curry(_append)
        
        return ranges.reduce(Result.success([Mark]())) { result, range in
            return (curriedAppend <^> result) <*> parse(context, range: range)
        }

    }
    
    static func parse(
        callback: @escaping (OMResult<[Mark]>) -> Void,
        context: Context,
        ranges: [Range<String.Index>]) {
        
        let queue = DispatchQueue.global(qos: .userInitiated)
        
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
        let chunks = _slice(array: ranges, into: 4)
        
        chunks.forEach { chunk in
            queue.async(group: group) {
                completion(result: parse(context, ranges: chunk))
            }
        }
        
        group.notify(queue: queue) {
            callback(asyncResult >>- sort)
        }

    }
    
    static func inlineMarkup(on text: String, range: Range<String.Index>) -> [Mark] {
        return Grammar.inline.markup(on: text, range: range)
    }
    
    static func matchParagraph(on text: String, _ marks: [Mark]) -> Result<[Mark]> {
        let combined = _combine(marks, name: "paragraph", processContent: curry(inlineMarkup)(text)) { $0.name == "line" }
        return .success(combined)
    }
    
    static func matchList(_ marks: [Mark]) -> Result<[Mark]> {
        return .success(_group(marks, name: "list") { $0.name == "list.item" })
    }
    
    static func matchTable(_ marks: [Mark]) -> Result<[Mark]> {
        return .success(_group(marks, name: "table") { $0.name.hasPrefix("table.") })
    }

    static func sort(_ marks: [Mark]) -> Result<[Mark]> {
        let sorted = marks.sorted { (m1, m2) -> Bool in
            return m1.range.lowerBound < m2.range.lowerBound
        }
        return .success(sorted)
    }
}

func _group(_ marks: [Mark],
            name: String,
            renameTo: String? = nil,
            parseContentWith grammer: Grammar? = nil,
            match: (Mark) -> Bool) -> [Mark] {
    
    
    guard let firstIndex = marks.index(where: match) else {
        return marks
    }
    var marks = marks
    //  var grouped = Array(marks[0..<firstIndex])
    var items = [marks[firstIndex]]
    var cursor = firstIndex + 1
    while cursor < marks.count && match(marks[cursor]) {
        items.append(marks[cursor])
        cursor += 1
    }
    //  marks.removeSubrange(firstIndex..<cursor)
    var group = Mark(name, marks: items)!
    if let newName = renameTo {
        items = items.map { mark in
            var m = mark
            m.name = newName
            return m
        }
    }
    group.marks = items
    marks.replaceSubrange(firstIndex..<cursor, with: [group])
    return _group(marks, name: name, renameTo: renameTo, match: match)
}

func _combine(_ marks: [Mark],
              name: String,
              processContent: (Range<String.Index>) -> [Mark],
              match: (Mark) -> Bool) -> [Mark] {
    guard let firstIndex = marks.index(where: match) else {
        return marks
    }
    var marks = marks
    //  var grouped = Array(marks[0..<firstIndex])
    var items = [marks[firstIndex]]
    var cursor = firstIndex + 1
    while cursor < marks.count && match(marks[cursor]) {
        items.append(marks[cursor])
        cursor += 1
    }
    //  marks.removeSubrange(firstIndex..<cursor)
    var group = Mark(name, marks: items)!
    //  if let newName = renameTo {
    //    items = items.map { mark in
    //      var m = mark
    //      m.name = newName
    //      return m
    //    }
    //  }
    group.marks = processContent(group.range)
    marks.replaceSubrange(firstIndex..<cursor, with: [group])
    return _combine(marks, name: name, processContent: processContent, match: match)
}
