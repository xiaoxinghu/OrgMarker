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
