//
//  Marker.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 13/03/17.
//  Copyright © 2017 Xiaoxing Hu. All rights reserved.
//

import Foundation
import Dispatch

struct Context {
    
    let text: String
    
    var range: Range<String.Index>
    
    var grammar: Grammar
    
    var threads: Int
    
    var marks: [Mark] = []
    
    var sections: [Mark] = []
    
    init(_ _text: String,
         range _range: Range<String.Index>? = nil,
         with _grammar: Grammar = Grammar.main(),
         threads _threads: Int = 4) {
        text = _text
        range = _range ?? _text.startIndex..<_text.endIndex
        grammar = _grammar
        threads = _threads
    }
}

public struct Marker {
    
    let todos: [[String]]
    public var threads: Int = 4
    
    public init(
        todos _todos: [[String]] = [["TODO"], ["DONE"]]) {
        todos = _todos
    }
    
    /// Mark the text. This function will sectionize the result if it is full text marking.
    ///
    /// - Parameters:
    ///   - text: the target text
    ///   - range: range to mark, for partial marking, full text marking if it is nil
    ///   - parallel: parallel marking, use to parse big files
    /// - Returns: marks
    public func mark(
        _ text: String,
        range: Range<String.Index>? = nil,
        parallel: Bool = false) -> OMResult<[Mark]> {
        var parseF = parallel ? parallelParse : singalTheadedParse
        if range == nil { // full text marking, sectionize
            parseF = parseF |> sectionize
        }
        let f = buildContext |> updateGrammar |> breakdown |> parseF |> extractResult
        return f((text, range))
    }
    
    private func extractResult(from context: Context) -> OMResult<[Mark]> {
        return .success(context.marks + context.sections)
    }
    
    private func buildContext(_ text: String, range: Range<String.Index>?) -> Result<Context> {
        let grammar = Grammar.main(todo: todos.flatMap { $0 })
        return .success(Context(text, range: range, with: grammar, threads: threads))
    }
}
