//
//  Serialization.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 16/03/17.
//
//

import Foundation

extension Mark {
    public func serialize(on text: String) -> [String : Any] {
        let nsRange = text.nsRange(from: range)
        var dict: [String : Any] = [
            "name": name,
            "location": nsRange.location,
            "length": nsRange.length,
            ]
        
        if !meta.isEmpty {
            dict["meta"] = meta
        }
        if !marks.isEmpty {
            dict["marks"] = marks.map { $0.serialize(on: text) }
        }
        return dict
    }
}
