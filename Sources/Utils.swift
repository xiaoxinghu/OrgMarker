//
//  Utils.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 23/03/17.
//
//

import Foundation

extension Grammar {
    func firstMatch(in text: String,
                    range: Range<String.Index>) throws -> (Pattern, RegexMatchingResult) {
        for pattern in patterns {
            if let m = pattern.match.expression.firstMatch(in: text, range: range) {
                return (pattern, m)
            }
        }
        throw Errors.cannotFindToken("Nothing matches")
    }
    
    func matches(in text: String,
                 range: Range<String.Index>) -> [(Pattern, RegexMatchingResult)] {
        
        var matches = [(Pattern, RegexMatchingResult)]()
        for pattern in patterns {
            matches += pattern.match.expression.matches(in: text, range: range).map { (pattern, $0) }
        }
        return matches
    }
    
    func markup(on text: String,
                range: Range<String.Index>) -> [Mark] {
        return matches(in: text, range: range).map(curry(buildMark)(text))
    }
    
    fileprivate func buildMark(on text: String, for result: (Pattern, RegexMatchingResult)) -> Mark {
        let (pattern, match) = result
        var mark = Mark(pattern.name, range: match.range)
        for capture in pattern.match.captures ?? [] {
            guard let c = match.captures[capture.index], !c.isEmpty else {
                continue
            }
            var cMark = Mark(capture.name, range: match.captures[capture.index]!)
            if let cGrammar = capture.grammar {
                cMark.marks = cGrammar.markup(on: text, range: cMark.range)
            }
            mark.include(cMark)
            mark.meta[cMark.name.relativePath(from: mark.name)] = cMark.value(on: text)
        }
        return mark
    }
    
    
    
    func parse(_ text: String,
               range: Range<String.Index>? = nil) throws -> [Mark] {
        var marks = [Mark]()
        
        func _parse(_ range: Range<String.Index>) throws -> Range<String.Index> {
            let (pattern, match) = try firstMatch(in: text, range: range)
            let newMark = buildMark(on: text, for: (pattern, match))
            marks.append(newMark)
            return match.range.upperBound..<range.upperBound
        }
        var range = range ?? text.startIndex..<text.endIndex
        while !range.isEmpty {
            range = try _parse(range)
        }
        return marks
    }
    
    func parse(_ text: String,
               ranges: [Range<String.Index>]) throws -> [Mark] {
        return try ranges.reduce([Mark]()) { result, range in
            return try result + parse(text, range: range)
        }
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
