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
                  options: NSRegularExpression.MatchingOptions = [],
                  range: NSRange) throws -> (Pattern, NSTextCheckingResult) {
    for pattern in patterns {
      if let m = pattern.match.expression.firstMatch(in: text, options: options, range: range) {
        return (pattern, m)
      }
    }
    throw Errors.cannotFindToken("Nothing matches")
  }
  
  func matches(in text: String,
               options: NSRegularExpression.MatchingOptions = [],
               range: NSRange) -> [(Pattern, NSTextCheckingResult)] {
    
    var matches = [(Pattern, NSTextCheckingResult)]()
    for pattern in patterns {
      matches += pattern.match.expression.matches(in: text, options: options, range: range).map { (pattern, $0) }
    }
    return matches
  }
  
  func markup(on text: String,
              options: NSRegularExpression.MatchingOptions = [],
              range: NSRange) -> [Mark] {
    return matches(in: text, options: options, range: range).map { (pattern, match) in
      return Mark(pattern.name, range: match.range)
    }
  }
  
  func parse(_ text: String,
             options: NSRegularExpression.MatchingOptions = [],
             range: NSRange? = nil) throws -> [Mark] {
    var marks = [Mark]()
    
    func _parse(_ range: NSRange) throws -> NSRange {
      let (pattern, match) = try firstMatch(in: text, options: options, range: range)
      var newMark = Mark(pattern.name, range: match.range)
      if let captures = pattern.match.captures {
        for capture in captures {
          if match.rangeAt(capture.index).length == 0 { continue }
          var cMark = Mark(capture.name, range: match.rangeAt(capture.index))
          if let cGrammar = capture.grammar {
            cMark.marks = cGrammar.markup(on: text, range: cMark.range)
          }
          newMark.include(cMark)
          newMark.meta[cMark.name.relativePath(from: newMark.name)] = cMark.value(on: text)
        }
      }
      marks.append(newMark)
      return NSMakeRange(range.location + match.range.length, range.length - match.range.length)
    }
    var range = range ?? NSMakeRange(0, text.characters.count)
    while range.length > 0 {
      range = try _parse(range)
    }
    return marks
  }
  
  func parse(_ text: String,
             options: NSRegularExpression.MatchingOptions = [],
             ranges: [NSRange]) throws -> [Mark] {
    return try ranges.reduce([Mark]()) { result, range in
      return try result + parse(text, options: options, range: range)
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
              processContent: (NSRange) -> [Mark],
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
