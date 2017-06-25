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

func tokenize(_ context: Context, range: Range<String.Index>) -> Result<[Mark]> {
    let grammar = context.grammar
    let text = context.text
    if range.isEmpty { return .success([]) }
    guard let (pattern, match) = grammar.firstMatchingPattern(in: text, range: range) else {
        return .failure(.cannotFindToken("Cannot find matching token"))
    }
    let newMark = buildMark(on: text, for: (pattern, match))
    let newRange = match.range.upperBound..<range.upperBound
    let theRest = tokenize(context, range: newRange)
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
    
    fileprivate func matchingPatterns(named name: String? = nil,
                                      in text: String,
                                      range: Range<String.Index>) -> [PatternMatch] {
        
        var _patterns = patterns
        if let patternName = name {
            _patterns = _patterns.filter { $0.name == patternName }
        }
        
        var matches = [PatternMatch]()
        
        func valid(rmr: RegexMatchingResult) -> Bool {
            return !matches.contains { _, r in r.range.overlaps(rmr.range) }
        }
        
        for p in _patterns {
            matches += p.match.expression
                .matches(in: text, range: range)
                .filter(valid)
                .map { (p, $0) }
        }
        return matches
    }
    
    func markup(only name: String? = nil,
                on text: String,
                range: Range<String.Index>) -> [Mark] {
        return matchingPatterns(named: name, in: text, range: range).map(curry(buildMark)(text))
    }
}
