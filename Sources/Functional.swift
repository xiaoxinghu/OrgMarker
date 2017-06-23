//
//  Functional.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 23/03/17.
//
//

import Foundation

typealias Result<T> = OMResult<T>

public enum OMResult<T> {
    case success(T)
    case failure(OMError)
}

extension Result {
    func map<U>(f: (T)->U) -> Result<U> {
        switch self {
        case .success(let t): return .success(f(t))
        case .failure(let err): return .failure(err)
        }
    }
    func flatMap<U>(f: (T)->Result<U>) -> Result<U> {
        switch self {
        case .success(let t): return f(t)
        case .failure(let err): return .failure(err)
        }
    }
    
    func apply<U>(_ f: Result<((T) -> U)>) -> Result<U> {
        return f.flatMap { self.map(f: $0) }
    }
}

precedencegroup MonadicPrecedenceLeft {
    associativity: right
    lowerThan: LogicalDisjunctionPrecedence
    higherThan: AssignmentPrecedence
}

infix operator |> : MonadicPrecedenceLeft
infix operator >>- : MonadicPrecedenceLeft
infix operator <*> : MonadicPrecedenceLeft
infix operator <^> : MonadicPrecedenceLeft

func <^> <T, U>(f: (T) -> U, a: Result<T>) -> Result<U> {
    return a.map(f: f)
}

func >>- <T, U>(a: Result<T>, f: (T) -> Result<U>) -> Result<U> {
    return a.flatMap(f: f)
}

func |> <T, U, V>(f: @escaping (T) -> Result<U>, g: @escaping (U) -> Result<V>) -> (T) -> Result<V> {
    return { x in f(x) >>- g }
}

func <*> <T, U>(f: Result<((T) -> U)>, a: Result<T>) -> Result<U> {
    return a.apply(f)
}

func curry<A, B, C>(_ f: @escaping (A, B) -> C) -> (A) -> (B) -> C {
    return { a in
        { b in
            f(a, b) } }
}

public func curry<A, B, C, D>(_ function: @escaping (A, B, C) -> D) -> (A) -> (B) -> (C) -> D {
    return { (a: A) -> (B) -> (C) -> D in
        { (b: B) -> (C) -> D in
            { (c: C) -> D in
                function(a, b, c) } } }
}
