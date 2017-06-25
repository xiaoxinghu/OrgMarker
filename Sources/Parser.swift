//
//  Parser.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 24/06/17.
//
//

import Foundation

func updateGrammar(context: Context) -> OMResult<Context> {
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

func breakdown(_ range: Range<String.Index>, _ context: Context) -> Result<(Context, [Range<String.Index>])> {
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

fileprivate func parse(_ context: Context, range: Range<String.Index>) -> OMResult<[Mark]> {
    let _mark = curry(tokenize)(context)
        |> curry(matchParagraph)(context.text)
        |> matchList
        |> matchTable
    return _mark(range)
}

//func parse(_ context: Context, ranges: [Range<String.Index>]) -> OMResult<[Mark]> {
//    let f = context.threads > 1 ? parallelParse : singalTheadedParse
//    return f(context, ranges)
//}

func singalTheadedParse(
    _ context: Context, ranges: [Range<String.Index>]) -> OMResult<[Mark]> {    
    return ranges.reduce(Result.success([Mark]())) { result, range in
        return (curry(_concat) <^> result) <*> parse(context, range: range)
    }
}

func parallelParse(
    context: Context,
    ranges: [Range<String.Index>]) -> OMResult<[Mark]> {
    
    let queue = DispatchQueue.global(qos: .userInitiated)
    
    var asyncResult: Result<[Mark]> = .success([Mark]())
    let resultQ = DispatchQueue(label: "com.orgmarker.result")
    
    let group = DispatchGroup()
    let chunks = _slice(array: ranges, into: context.threads)
    
    chunks.forEach { chunk in
        queue.async(group: group) {
            let r = singalTheadedParse(context, ranges: chunk)
            resultQ.sync {
                asyncResult = (curry(_concat) <^> asyncResult) <*> r
            }
        }
    }
    
    group.wait()
    return asyncResult >>- sort
    //        group.notify(queue: queue) {
    //            callback(asyncResult >>- sort)
    //        }
    
}

fileprivate func _concat(marks1: [Mark], marks2: [Mark]) -> [Mark] {
    return marks1 + marks2
}

fileprivate func inlineMarkup(on text: String, range: Range<String.Index>) -> [Mark] {
    return Grammar.inline.markup(on: text, range: range)
}

fileprivate func matchParagraph(on text: String, _ marks: [Mark]) -> Result<[Mark]> {
    let combined = _combine(marks, name: "paragraph", processContent: curry(inlineMarkup)(text)) { $0.name == "line" }
    return .success(combined)
}

fileprivate func matchList(_ marks: [Mark]) -> Result<[Mark]> {
    return .success(_group(marks, name: "list") { $0.name == "list.item" })
}

fileprivate func matchTable(_ marks: [Mark]) -> Result<[Mark]> {
    return .success(_group(marks, name: "table") { $0.name.hasPrefix("table.") })
}

fileprivate func sort(_ marks: [Mark]) -> Result<[Mark]> {
    let sorted = marks.sorted { (m1, m2) -> Bool in
        return m1.range.lowerBound < m2.range.lowerBound
    }
    return .success(sorted)
}

fileprivate func addSectionInfo(_ marks: [Mark], at index: Int) -> [Mark] {
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
        return addSectionInfo(result, at: headline)
    }
    
    return .success(marks)
}

fileprivate func _group(_ marks: [Mark],
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

fileprivate func _combine(_ marks: [Mark],
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
