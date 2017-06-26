//
//  Lexer.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 24/06/17.
//
//

import Foundation

fileprivate func buildMark(on text: String, for result: PatternMatch) -> Mark {
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

func tokenize(_ context: Context) -> Result<[Mark]> {
    let grammar = context.grammar
    let text = context.text
    let range = context.range
    if range.isEmpty { return .success([]) }
    guard let (pattern, match) = grammar.firstMatchingPattern(in: text, range: range) else {
        return .failure(.cannotFindToken("Cannot find matching token"))
    }
    let newMark = buildMark(on: text, for: (pattern, match))
    var newContext = context
    newContext.range = match.range.upperBound..<range.upperBound
    let theRest = tokenize(newContext)
    return theRest.map { [newMark] + $0 }
}

extension Grammar {
    func firstMatchingPattern(named name: String? = nil,
                              in text: String,
                              range: Range<String.Index>) -> PatternMatch? {
        var _patterns = patterns
        var options: RegularExpression.MatchingOptions = .anchored
        if let patternName = name {
            _patterns = _patterns.filter { $0.name == patternName }
            options = []
        }
        for pattern in _patterns {
            if let m = pattern
                .match
                .expression
                .firstMatch(in: text, options: options, range: range) {
                return (pattern, m)
            }
        }
        return nil
    }
    
    func matchingPatterns(in text: String,
                          range: Range<String.Index>) -> [PatternMatch] {
        
        
        var matches = [PatternMatch]()
        
        func valid(rmr: RegexMatchingResult) -> Bool {
            return !matches.contains { _, r in r.range.overlaps(rmr.range) }
        }
        
        for p in patterns {
            matches += p.match.expression
                .matches(in: text, range: range)
                .filter(valid)
                .map { (p, $0) }
        }
        return matches
    }
    
    func matchingPatterns(
        named name: String,
        in text: String,
        range: Range<String.Index>) -> [PatternMatch] {
        let pattern = patterns.first { $0.name == name }!
        var range = range
        
        var matches = [PatternMatch]()
        while !range.isEmpty,
            let match = pattern.match.expression.firstMatch(in: text, range: range) {
                matches.append((pattern, match))
                range = match.range.upperBound..<range.upperBound
        }
        return matches
    }
    
    fileprivate func matching(
        pattern: Pattern,
        in text: String,
        range: Range<String.Index>) -> [RegexMatchingResult] {
        var range = range
        
        var matches = [RegexMatchingResult]()
        while !range.isEmpty,
            let match = pattern.match.expression.firstMatch(in: text, range: range) {
                matches.append(match)
                range = match.range.upperBound..<range.upperBound
        }
        return matches
    }
    
    func markup(only name: String? = nil,
                on text: String,
                range: Range<String.Index>) -> [Mark] {
        if let name = name {
            return matchingPatterns(named: name, in: text, range: range).map(curry(buildMark)(text))
        }
        return matchingPatterns(in: text, range: range).map(curry(buildMark)(text))
        
    }
}
