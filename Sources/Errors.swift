//
//  Errors.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 22/06/17.
//
//

import Foundation

public enum Errors: Error {
    case unexpectedToken(String)
    case cannotFindToken(String)
    case illegalNodeForContainer(String)
    case other(String)
}
