//
//  Mark.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 13/03/17.
//  Copyright © 2017 Xiaoxing Hu. All rights reserved.
//

import Foundation

public struct Mark {
    // MARK: properties
    public var range: Range<String.Index>
    public var name: String
    public var meta = [String : String]()
    public var marks = [Mark]()
    
    // MARK: init
    init(_ _name: String, range _range: Range<String.Index>) {
        name = _name
        range = _range
    }
    
    init?(_ _name: String, marks: [Mark]) {
        if marks.isEmpty { return nil }
        name = _name
        // TODO maybe need more logic, cannot rely on the order
        range = marks.first!.range.lowerBound..<marks.last!.range.upperBound
    }
    
    // MARK: func
    mutating func include(_ mark: Mark) {
        marks.append(mark)
    }
    
    func value(on text: String) -> String {
        return text.substring(with: range)
    }
    
    public subscript(_name: String) -> Mark? {
        get {
            return marks.first { mark in
                let n = mark.name[name.endIndex..<mark.name.endIndex]
                return n == _name
            }
        }
    }
    
    func prefix(with prefix: String) -> Mark {
        var m = Mark("\(prefix).\(name)", range: range)
        m.marks = marks.map { $0.prefix(with: prefix) }
        return m
    }
    
}


extension Mark: CustomStringConvertible {
    public var description: String {
        return "Mark(name: \(name))"
    }
}

extension Mark: Equatable {
    public static func == (lhs: Mark, rhs: Mark) -> Bool {
        return lhs.name == rhs.name && lhs.range == rhs.range
    }
}

extension String {
    func scope(under name: String) -> Bool {
        return self.hasPrefix(name) && self.characters.count > name.characters.count
    }
}
