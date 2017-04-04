//
//  Grammar.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 11/03/17.
//  Copyright © 2017 Xiaoxing Hu. All rights reserved.
//

import Foundation

let space = "[ \\t]"
let newline = "\\n"
let eol = "(?:\(newline)|\\Z)" // end of line

fileprivate func surrounded(by mark: String) -> String {
  return "\(mark)[^\(mark)]+\(mark)"
}

struct Grammar {
  var patterns: [Pattern]
  
  
  mutating func modify(pattern name: String, to become: (Pattern) -> Pattern) {
    guard let index = patterns.index(where: { $0.name == name }) else {
      return
    }
    
    patterns[index] = become(patterns[index])
    
  }
  
  static func main(
    todo: [String] = ["TODO", "DONE"],
    priority: String = "ABC",
    planning: [String] = ["DEADLINE", "SCHEDULED", "CLOSED"]) -> Grammar {
    
    let todoPattern = "(?:(\(todo.joined(separator: "|")))\(space)+)"
    let priorityPattern = "(?:\\[#([\(priority)])\\]\\s+)"
    let planningKeywordPattern = "(\(planning.joined(separator: "|")))"
    let tagsPattern = "(?:\(space)+((?:\\:.+)+\\:)\(space)*)"
    
    return Grammar(patterns: [
      Pattern("blank", match: "^\(space)*\(eol)"),
      
      Pattern("setting", match: "^#\\+([a-zA-Z_]+):\(space)*([^\\n]*)\(eol)",
        captures: [ Capture(1, name: "setting.key"), Capture(2, name: "setting.value") ]),
      
      Pattern("headline", match: "^(\\*+)\(space)\(todoPattern)?\(priorityPattern)?(.*?)\(tagsPattern)?\(eol)",
        captures: [
          Capture(1, name: "headline.stars"),
          Capture(2, name: "headline.keyword"),
          Capture(3, name: "headline.priority"),
          Capture(4, name: "headline.text", parseWith: Grammar.inline),
          Capture(5, name: "headline.tags")
        ]),
      
      Pattern("planning", match: "^\(space)*\(planningKeywordPattern):\(space)+(.+?)\(space)*\(eol)",
        captures: [ Capture(1, name: "planning.keyword"), Capture(2, name: "planning.timestamp") ]),
      
      
      
      Pattern("horizontalRule", match: "^\(space)*-{5,}\(eol)"),
      
      Pattern("comment", match: "^\(space)*#\(space)+(.*)\(eol)"),
      
      Pattern("list.item", match: "^(\(space)*)([-+*]|\\d+(?:\\.|\\)))\(space)+(?:(\\[[ X-]\\])\(space)+)?(.*)\(eol)",
        captures: [
          Capture(1, name: "list.item.indent"),
          Capture(2, name: "list.item.bullet"),
          Capture(3, name: "list.item.checker"),
          Capture(4, name: "list.item.text", parseWith: Grammar.inline),
          ]),
      
      Pattern("footnote", match: "^\\[fn:(\\d+)\\](?:\(space)+(.*))?\(eol)",
        captures: [ Capture(1, name: "footnote.label"), Capture(2, name: "footnote.content") ]),
      
      Pattern("table.separator", match: "^\(space)*\\|-.*\(eol)"),
      Pattern("table.row", match: "^\(space)*\\|(?:[^\\r\\n\\|]*\\|?)+\(eol)"),
      
      Pattern("block", match: "^\(space)*#\\+begin_([a-z]+)(?:\(space)+([^\\n]*))?\(eol)(.*?\(eol))??\(space)*#\\+end_\\1\(eol)",
        options: [.caseInsensitive, .dotMatchesLineSeparators],
        captures: [
          Capture(1, name: "block.type"),
          Capture(2, name: "block.params"),
          Capture(3, name: "block.content"),
          ]),
      
      Pattern("drawer", match: "^\(space)*:((?!end|END)[a-zA-Z]+):\(space)*\(eol)(.*?\(eol))??\(space)*:(end|END):\(space)*\(eol)",
        options: [.caseInsensitive, .dotMatchesLineSeparators],
        captures: [
          Capture(1, name: "drawer.name"),
          Capture(2, name: "drawer.content"),
          ]),
      
      Pattern("line", match: "^[^\\n]+\(eol)"),
      ])
  }
  
  static let blockContent = Grammar(patterns: [
    Pattern("block.content", match: ".*")
    ])
  
  static let inline = Grammar(patterns: [
    Pattern("link", match: "\\[\\[([^\\]]*)\\](?:\\[([^\\]]*)\\])?\\]",
            options: [.dotMatchesLineSeparators],
            captures: [
              Capture(1, name: "link.url"),
              Capture(2, name: "link.text"),
              ]),
    Pattern("code", match: surrounded(by: "~")),
    Pattern("verbatim", match: surrounded(by: "=")),
    Pattern("bold", match: surrounded(by: "\\*")),
    Pattern("italic", match: surrounded(by: "/")),
    Pattern("underlined", match: surrounded(by: "_")),
    Pattern("strikeThrough", match: surrounded(by: "\\+")),
    ])
}
