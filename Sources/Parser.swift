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
    
    if updatedGrammar != nil {
        var context = context
        context.grammar = updatedGrammar!
        return .success(context)
    } else {
        return .success(context)
    }
}

func breakdown(_ context: Context) -> Result<[Context]> {
    let grammar = context.grammar
    let text = context.text
    let range = context.range
    let matches = grammar.matchingPatterns(named: "headline", in: text, range: range)    
    var ranges = matches.reduce([Range<String.Index>]()) { all, match in
        let (_, match) = match
        if all.isEmpty {
            return [range.lowerBound..<match.range.lowerBound]
        } else {
            return all + [all.last!.upperBound..<match.range.lowerBound]
        }
    }
    if ranges.isEmpty { ranges = [range] }
    else { ranges.append(ranges.last!.upperBound..<range.upperBound) }
    
    let contexts: [Context] = ranges.map { range in
        var context = context
        context.range = range
        return context
    }
    return .success(contexts)
}

fileprivate func parse(_ context: Context) -> OMResult<[Mark]> {
    let _mark = tokenize
        |> curry(matchParagraph)(context.text)
        |> matchList
        |> matchTable
    return _mark(context)
}

func singalTheadedParse(
    _ contexts: [Context]) -> OMResult<Context> {
    return contexts.reduce(Result.success(contexts[0])) { result, context in
        return (curry(_append) <^> parse(context)) <*> result
    }
}

func parallelParse(contexts: [Context]) -> OMResult<Context> {
    
    let queue = DispatchQueue.global(qos: .userInitiated)
    
    var result = OMResult.success(contexts[0])
//    var asyncResult: Result<[Mark]> = .success([Mark]())
    let resultQ = DispatchQueue(label: "com.orgmarker.result")
    
    let group = DispatchGroup()
    
    let chunks = _slice(array: contexts, into: contexts[0].threads)
    
//    let chunks: [Context] = _slice(array: context.parts, into: context.threads).map { ranges in
//        var c = context
//        c.parts = ranges
//        return c
//    }
    
    chunks.forEach { chunk in
        queue.async(group: group) {
            let r = singalTheadedParse(chunk)
            resultQ.sync {
                result = (curry(_concat) <^> r) <*> result
            }
        }
    }
    
    group.wait()
    return result >>- sort
}

fileprivate func _append(marks: [Mark], to context: Context) -> Context {
    var context = context
    context.marks = context.marks + marks
    return context
}

fileprivate func _concat(context1: Context, context2: Context) -> Context {
    var context = context1
    context.marks = context.marks + context2.marks
    return context
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

//fileprivate func sort(_ marks: [Mark]) -> Result<[Mark]> {
//    let sorted = marks.sorted { (m1, m2) -> Bool in
//        return m1.range.lowerBound < m2.range.lowerBound
//    }
//    return .success(sorted)
//}

fileprivate func sort(_ context: Context) -> Result<Context> {
    let sorted = context.marks.sorted { (m1, m2) -> Bool in
        return m1.range.lowerBound < m2.range.lowerBound
    }
    var c = context
    c.marks = sorted
    return .success(c)
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

func sectionize(_ context: Context) -> Result<Context> {    
    let headlines = context.marks.filter { $0.name == "headline" }
    
    var sections = [Mark]()
    var openSections = [Mark]()
    
    for headline in headlines {
        // try to close open sections
        while var last = openSections.last {
            if last.meta[".stars"]!.characters.count < headline.meta[".stars"]!.characters.count {
                break
            }
            
            last.range = last.range.lowerBound..<headline.range.lowerBound
            sections.append(last)
            openSections.removeLast()
        }
        // add self to open sections
        var section = Mark("section", range: headline.range.lowerBound..<headline.range.lowerBound)
        section.meta[".stars"] = headline.meta[".stars"]!
        openSections.append(section)
    }
    
    let rest: [Mark] = openSections.map { os in
        var section = os
        section.range = section.range.lowerBound..<context.text.endIndex
        return section
    }
    
    sections.append(contentsOf: rest)
    
    var context = context
    context.sections = sections
    return .success(context)
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
