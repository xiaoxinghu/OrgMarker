//
//  Obsolete.swift
//  OrgMarker
//
//  Created by Xiaoxing Hu on 27/03/17.
//
//

import Foundation

// TODO this code is not complete
fileprivate func _matchMaking(_ marks: [Mark],
                  name: String,
                  matchBegin: (Mark) -> Bool,
                  matchEnd: (Mark) -> Bool,
                  markContent: (NSRange) -> [Mark],
                  beginFallback: (Mark) -> Mark) -> [Mark] {
  var marks = marks
  var begins = [(Int, Mark)]()
  var index = 0
  
  while index < marks.count {
    let mark = marks[index]
    if matchBegin(mark) {
      begins.append((index, mark))
      index += 1
      continue
    }
    
    if let (beginIndex, beginMark) = begins.first,
      matchEnd(mark),
      beginIndex < index {
      let contentRange = NSUnionRange(marks[beginIndex + 1].range, marks[index - 1].range)
      var contentMarks = [beginMark]
      contentMarks.append(contentsOf: markContent(contentRange))
      contentMarks.append(mark)
      marks.removeSubrange(beginIndex..<index+1)
      var container = Mark(name, marks: contentMarks)!
      container.marks = contentMarks
      marks.insert(container, at: beginIndex)
      begins.removeAll()
      index = beginIndex + 1
      continue
    }
    
    index += 1
  }
  
  return marks
}

// TODO What's wrong with this code, in spite of performance.
// It seems that tho code is not thread safe
//fileprivate func _matchMaking(_ marks: [Mark],
//                             name: String,
//                             matchBegin: (Mark) -> Bool,
//                             matchEnd: (Mark) -> Bool,
//                             markContent: (NSRange) -> [Mark],
//                             beginFallback: (Mark) -> Mark) -> [Mark] {
//
//  var marks = marks
//  guard let beginIndex = marks.index(where: matchBegin) else {
//    return marks
//  }
//
//  let begin = marks[beginIndex]
//
//  guard let endIndex = marks[beginIndex+1..<marks.endIndex].index(where: matchEnd) else {
//    marks[beginIndex] = beginFallback(marks[beginIndex])
//    return _matchMaking(marks, name: name, matchBegin: matchBegin, matchEnd: matchEnd, markContent: markContent, beginFallback: beginFallback)
//  }
//  let end = marks[endIndex]
//
//  let contentRange = NSUnionRange(marks[beginIndex + 1].range, marks[endIndex - 1].range)
//  var contentMarks = [begin]
//  contentMarks.append(contentsOf: markContent(contentRange))
//  contentMarks.append(end)
//  marks.removeSubrange(beginIndex..<endIndex+1)
//  var container = Mark(name, marks: contentMarks)!
//  container.marks = contentMarks
//  marks.insert(container, at: beginIndex)
//  return _matchMaking(marks, name: name, matchBegin: matchBegin, matchEnd: matchEnd, markContent: markContent, beginFallback: beginFallback)
//}

//func _group(_ marks: [Mark],
//            name: String,
//            renameTo: String? = nil,
//            match: (Mark) -> Bool) -> [Mark] {
//
//  guard let firstIndex = marks.index(where: match) else {
//    return marks
//  }
//  var grouped = Array(marks[0..<firstIndex])
//  var items = [marks[firstIndex]]
//  var cursor = firstIndex + 1
//  while cursor < marks.count && match(marks[cursor]) {
//    items.append(marks[cursor])
//    cursor += 1
//  }
//  //  marks.removeSubrange(firstIndex..<cursor)
//  var group = Mark(name, marks: items)!
//  if let newName = renameTo {
//    items = items.map { mark in
//      var m = mark
//      m.name = newName
//      return m
//    }
//  }
//  group.marks = items
//  grouped.append(group)
//  return grouped + _group(Array(marks[cursor..<marks.count]), name: name, renameTo: renameTo, match: match)
//}

fileprivate extension Marker {
  func matchBlocks(_ marks: [Mark]) -> Result<[Mark]> {
    var blockType = ""
    
    return .success(
      _matchMaking(
        marks, name: "block",
        matchBegin: { mark in
          if mark.name == "block.begin" {
            blockType = mark.meta[".type"]!.lowercased()
            return true
          }
          return false
      }, matchEnd: { mark in
        return mark.name == "block.end"
          && mark.meta[".type"]!.lowercased() == blockType
      }, markContent: { range in
        return [Mark("block.content", range: range)]
      }, beginFallback: { mark in
        return mark
      })
    )
  }
  
  func matchDrawers(_ marks: [Mark]) -> Result<[Mark]> {
    return .success(
      _matchMaking(
        marks, name: "drawer",
        matchBegin: { mark in
          return mark.name == "drawer.begin"
      }, matchEnd: { mark in
        return mark.name == "drawer.end"
      }, markContent: { range in
        return [Mark("drawer.content", range: range)]
      }, beginFallback: { mark in
        var mark = mark
        mark.name = "line"
        return mark
      })
    )
  }

}
