//
//  Tree.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 17/03/17.
//
//

import Foundation

public class Node<T> {
  public var value: T
  public var children = [Node<T>]()
  public var parent: Node<T>?
  
  public init(_ _value: T) {
    value = _value
  }
  
  public func add(child node: Node<T>) -> Node<T> {
    node.parent = self
    children.append(node)
    return node
  }
  
  public func add(child _value: T) -> Node<T> {
    let node = Node(_value)
    return add(child: node)
  }
}

extension Node {
  public var lastLeaf: Node {
    if let lastChild = children.last {
      return lastChild.lastLeaf
    }
    return self
  }
  
//  public func search(where condition: (Node) -> Bool) -> Node? {
//    return children.first(where: condition)
//  }
}

typealias OrgMark = Node<Mark>
