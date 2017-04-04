//
//  Pattern.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 13/03/17.
//  Copyright © 2017 Xiaoxing Hu. All rights reserved.
//

import Foundation

struct Capture {
  let index: Int
  let name: String
  let grammar: Grammar?
  
  init(_ _index: Int,
       name _name: String,
       parseWith _grammar: Grammar? = nil) {
    index = _index
    name = _name
    grammar = _grammar
  }
}

struct Match {
  let pattern: String
  let captures: [Capture]?
  let expression: RegularExpression

  init(_ _pattern: String,
       options: RegularExpression.Options = [],
       captures _captures: [Capture]? = nil) {
    pattern = _pattern
    captures = _captures
    expression = try! RegularExpression(
      pattern: pattern, options: options)
  }
}

struct Pattern {
  let name: String
  let match: Match

  init(_ _name: String,
       match _match: String,
       options: RegularExpression.Options = [],
       captures: [Capture]? = nil) {
    name = _name
    match = Match(_match, options: options, captures: captures)
  }
}
