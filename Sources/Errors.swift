//
//  Errors.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 22/06/17.
//
//

import Foundation

// TODO: better error types
public enum OMError: Error {
    case unexpectedToken(String)
    case cannotFindToken(String)
    case illegalNodeForContainer(String)
    case other(Error)
}
