import Cocoa

/// Cell view that draws the graph lines next to the text.
class XTHistoryCellView: NSTableCellView
{
  typealias GitCommitEntry = CommitEntry
  
  var refs = [String]()
  
  /// Margin of space to leave for the lines in this cell.
  fileprivate var linesMargin: CGFloat = 0.0
  
  static let lineColors = [
      NSColor.blue, NSColor.green, NSColor.red,
      NSColor.brown, NSColor.cyan, NSColor.darkGray,
      NSColor.magenta, NSColor.orange, NSColor.purple,
      // Regular yellow is too light
      NSColor(calibratedHue: 0.13, saturation: 0.08, brightness: 0.8, alpha: 1.0),
      NSColor.black, NSColor.lightGray]
  
  struct Widths
  {
    static let line: CGFloat = 2.0
    static let column: CGFloat = 8.0
  }
  struct Margins
  {
    static let left: CGFloat = 4.0
    static let right: CGFloat = 4.0
    static let text: CGFloat = 4.0
    static let token: CGFloat = 4.0
  }

  /// Finds the center of the given column.
  static func columnCenter(_ index: UInt) -> CGFloat
  {
    return Margins.left + Widths.column * CGFloat(index) + Widths.column / 2
  }
  
  /// Moves the text field out of the way of the lines and refs.
  func adjustLayout()
  {
    guard let entry = objectValue as? GitCommitEntry
    else { return }
    
    let totalColumns = entry.lines.reduce(0) { (oldMax, line) -> UInt in
      max(oldMax, line.parentIndex ?? 0, line.childIndex ?? 0)
    }
    
    linesMargin = Margins.left + CGFloat(totalColumns + 1) * Widths.column
    
    let tokenWidth: CGFloat = refs.reduce(0.0) { (width, ref) -> CGFloat in
      guard let (_, displayRef) = ref.splitRefName()
      else { return 0 }
      return XTRefToken.rectWidth(text: displayRef) + width + Margins.token
    }
    
    if let textField = textField {
      var newFrame = textField.frame
      
      newFrame.origin.x = tokenWidth + linesMargin + Margins.text
      newFrame.size.width = frame.size.width - newFrame.origin.x - Margins.right
      textField.frame = newFrame
    }
  }
  
  /// Draws the graph lines and refs in the view.
  override func draw(_ dirtyRect: NSRect)
  {
    super.draw(dirtyRect)
    
    adjustLayout()
    drawRefs()
    drawLines()
  }
  
  static func refType(_ typeName: String) -> XTRefType
  {
    switch typeName {
      case "refs/heads/":
        return .branch
      case "refs/remotes/":
        return .remoteBranch
      case "refs/tags/":
        return .tag
      default:
        return .unknown
    }
  }
  
  func drawRefs()
  {
    var x: CGFloat = linesMargin + Margins.token
    
    for ref in refs {
      guard let (refTypeName, displayRef) = ref.splitRefName()
      else { continue }
      
      let refRect = NSRect(x: x, y: -1,
                           width: XTRefToken.rectWidth(text: displayRef),
                           height: frame.size.height)
      
      XTRefToken.drawToken(refType: XTHistoryCellView.refType(refTypeName),
                           text: displayRef,
                           rect: refRect)
      x += refRect.size.width + Margins.token
    }
  }
  
  func cornerOffset(_ offset1: UInt, _ offset2: UInt) -> CGFloat
  {
    let pathOffset = abs(Int(offset1) - Int(offset2))
    let height = Double(pathOffset) * 0.25
    
    return min(CGFloat(height), Widths.line)
  }
  
  func path(for line: HistoryLine) -> NSBezierPath?
  {
    guard let dotOffset = (objectValue as? GitCommitEntry)?.dotOffset
    else { return nil }
    let path = NSBezierPath()
    
    switch (line.parentIndex, line.childIndex) {
      
      case (nil, let childIndex?):
        path.move(to: NSPoint(x: XTHistoryCellView.columnCenter(childIndex),
                              y: bounds.size.height))
        path.relativeLine(to: NSPoint(x: 0, y: -cornerOffset(dotOffset,
                                                             childIndex)))
        path.line(to: NSPoint(x: XTHistoryCellView.columnCenter(dotOffset),
                              y: bounds.size.height/2))
      
      case (let parentIndex?, nil):
        path.move(to: NSPoint(x: XTHistoryCellView.columnCenter(parentIndex),
                              y: 0))
        path.relativeLine(to: NSPoint(x: 0, y: cornerOffset(dotOffset,
                                                            parentIndex)))
        path.line(to: NSPoint(x: XTHistoryCellView.columnCenter(dotOffset),
                              y: bounds.size.height/2))
      
      case (let parentIndex?, let childIndex?):
        path.move(to: NSPoint(x: XTHistoryCellView.columnCenter(childIndex),
                              y: bounds.size.height))
        if parentIndex != childIndex {
          let cornerOffset = self.cornerOffset(childIndex, parentIndex)
          
          path.relativeLine(to: NSPoint(x: 0, y: -cornerOffset))
          path.line(to: NSPoint(x: XTHistoryCellView.columnCenter(parentIndex),
                                y: cornerOffset))
        }
        path.line(to: NSPoint(x: XTHistoryCellView.columnCenter(parentIndex),
                              y: 0))
      
      case (nil, nil):
        return nil
    }
    return path
  }
  
  func drawLines()
  {
    guard let entry = objectValue as? GitCommitEntry,
          let dotOffset = entry.dotOffset,
          let dotColorIndex = entry.dotColorIndex
    else { return }
    
    for line in entry.lines {
      guard let path = path(for: line)
      else { continue }
      
      let colorIndex = Int(line.colorIndex) %
                       XTHistoryCellView.lineColors.count
      let lineColor =  XTHistoryCellView.lineColors[colorIndex]
      
      path.lineJoinStyle = .roundLineJoinStyle
      if line.parentIndex != line.childIndex {
        NSColor.white.setStroke()
        path.lineWidth = Widths.line + 1.0
        path.stroke()
      }
      lineColor.setStroke()
      path.lineWidth = Widths.line
      path.stroke()
      
      let dotSize: CGFloat = 6.0
      let dotPath = NSBezierPath(ovalIn:
              NSRect(x: XTHistoryCellView.columnCenter(dotOffset) - dotSize/2,
                     y: bounds.size.height/2 - dotSize/2,
                     width: dotSize, height: dotSize))
      let dotColorIndex = Int(dotColorIndex) %
                          XTHistoryCellView.lineColors.count
      let baseDotColor = XTHistoryCellView.lineColors[dotColorIndex]
      let dotColor = baseDotColor.shadow(withLevel: 0.5) ?? baseDotColor
      
      NSColor.white.setStroke()
      dotPath.lineWidth = 1.0
      dotPath.stroke()
      dotColor.setFill()
      dotPath.fill()
    }
  }
  
}
