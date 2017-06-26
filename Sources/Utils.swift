//
//  Utils.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 23/03/17.
//
//

import Foundation

typealias PatternMatch = ((Pattern, RegexMatchingResult))

func _slice<T>(array: Array<T>, into parts: Int) -> [Array<T>] {
    let chunkSize = Int(ceil(Double(array.count) / Double(parts)))
    let sections = (0..<parts)
    return sections.map { i in
        let from = i * chunkSize
        let to = min((i + 1) * chunkSize, array.count)
        return Array(array[from..<to])
    }
}
