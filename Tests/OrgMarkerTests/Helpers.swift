//
//  TestUtilities.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 31/03/17.
//
//

import Foundation
import XCTest
@testable import OrgMarker

enum AssertionResult {
    case success
    case failure(String)
}

typealias ExpFunc = (Mark) -> AssertionResult

func beNamed(_ name: String) -> ExpFunc {
    return { mark in
        return mark.name == name ? .success : .failure("real name: \(mark.name)")
    }
}

func haveMeta(key: String, value: String) -> ExpFunc {
    return { mark in
        return mark.meta[key] == value ? .success : .failure("no meta key: \(key), value: \(value)")
    }
}

func haveValue(_ value: String, on text: String) -> ExpFunc {
    return { mark in
        let markedText = mark.value(on: text)
        return markedText == value ? .success : .failure("expected: \(value), marked: \(markedText)")
    }
}

func haveMark(_ name: String? = nil, to match: @escaping ExpFunc = { _ in .success }) -> ExpFunc {
    return { mark in
        var candidates = mark.marks
        if let name = name {
            candidates = mark.marks.filter { $0.name == name }
            if candidates.isEmpty { return .failure("can't find mark with name: \(name)") }
        }
        var errors = [String]()
        for m in candidates {
            switch match(m) {
            case .success:
                return .success
            case .failure(let msg):
                errors += [msg]
            }
        }
        return .failure("can't find matching mark. errors: [\(errors.joined(separator: ", "))]")
    }
}



func expect(_ mark: Mark,
            file: StaticString = #file, line: UInt = #line,
            to expectation: ExpFunc) {
    switch expectation(mark) {
    case .failure(let message):
        XCTFail(message, file: file, line: line)
    case .success:
        return
    }
}

func mark(_ string: String, file: StaticString = #file, line: UInt = #line) -> [Mark] {
    let marker = Marker()
    switch marker.mark(string) {
    case .success(let marks):
        return marks
    case .failure(let error):
        fatalError("> mark failed: \(error)", file: file, line: line)
    }
}

func mark(_ lines: [String], file: StaticString = #file, line: UInt = #line) -> [Mark] {
    return mark(lines.joined(separator: "\n"))
}
