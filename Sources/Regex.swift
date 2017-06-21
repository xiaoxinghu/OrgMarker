//
//  Regex.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 15/03/17.
//
//

import Foundation

#if !os(Linux)
    typealias RegularExpression = NSRegularExpression
    typealias TextCheckingResult = NSTextCheckingResult
#else
    extension TextCheckingResult {
        func rangeAt(_ idx: Int) -> NSRange {
            return range(at: idx)
        }
    }
#endif

struct RegexMatchingResult {
    let range: Range<String.Index>
    let captures: [Range<String.Index>?]
}

fileprivate func transform(on string: String, result: TextCheckingResult) -> RegexMatchingResult {
    return RegexMatchingResult(
        range: string.range(from: result.range)!,
        captures: (0..<result.numberOfRanges)
            .map { result.rangeAt($0) }
            .map { string.range(from: $0) })
}

extension RegularExpression {
    func firstMatch(in string: String, range: Range<String.Index>) -> RegexMatchingResult? {
        guard let result = firstMatch(
            in: string,
            options: [],
            range: string.nsRange(from: range)) else {
                return nil
        }
        
        return transform(on: string, result: result)
    }
    
    func matches(in string: String, range: Range<String.Index>) -> [RegexMatchingResult] {
        let result = matches(
            in: string,
            options: [],
            range: string.nsRange(from: range))
        
        return result.map { transform(on: string, result: $0) }
    }
}
