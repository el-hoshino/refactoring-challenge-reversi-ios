import UIKit

private let lineWidth: CGFloat = 2

public class BoardView: UIView {
    private var cellViews: [CellView] = []
    private var actions: [CellSelectionAction] = []
    private var animationCanceller: Canceller?
    
    var isAnimating: Bool { animationCanceller != nil }
    
    public struct Size {
        var width: Int
        var height: Int
    }
    
    /// 盤のサイズを設定します。
    public var boardSize: Size = .init(width: 0, height: 0) {
        didSet {
            setUp()
        }
    }
    
    var width: Int { boardSize.width }
    var height: Int { boardSize.height }
    
    private var xRange: Range<Int> { 0 ..< width }
    
    private var yRange: Range<Int> { 0 ..< height }
    
    /// セルがタップされたときの挙動を移譲するためのオブジェクトです。
    public weak var delegate: BoardViewDelegate?
    
    private func setUp() {
        self.backgroundColor = UIColor(named: "DarkColor")!
        
        let cellViews: [CellView] = (0 ..< (width * height)).map { _ in
            let cellView = CellView()
            cellView.translatesAutoresizingMaskIntoConstraints = false
            return cellView
        }
        self.cellViews = cellViews
        
        cellViews.forEach(self.addSubview(_:))
        for i in cellViews.indices.dropFirst() {
            NSLayoutConstraint.activate([
                cellViews[0].widthAnchor.constraint(equalTo: cellViews[i].widthAnchor),
                cellViews[0].heightAnchor.constraint(equalTo: cellViews[i].heightAnchor),
            ])
        }
        
        cellViews.first.map {
            $0.widthAnchor.constraint(equalTo: $0.heightAnchor).isActive = true
        }
        
        for y in yRange {
            for x in xRange {
                let topNeighborAnchor: NSLayoutYAxisAnchor
                if let cellView = cellViewAt(x: x, y: y - 1) {
                    topNeighborAnchor = cellView.bottomAnchor
                } else {
                    topNeighborAnchor = self.topAnchor
                }
                
                let leftNeighborAnchor: NSLayoutXAxisAnchor
                if let cellView = cellViewAt(x: x - 1, y: y) {
                    leftNeighborAnchor = cellView.rightAnchor
                } else {
                    leftNeighborAnchor = self.leftAnchor
                }
                
                let cellView = cellViewAt(x: x, y: y)!
                NSLayoutConstraint.activate([
                    cellView.topAnchor.constraint(equalTo: topNeighborAnchor, constant: lineWidth),
                    cellView.leftAnchor.constraint(equalTo: leftNeighborAnchor, constant: lineWidth),
                ])
                
                if y == height - 1 {
                    NSLayoutConstraint.activate([
                        self.bottomAnchor.constraint(equalTo: cellView.bottomAnchor, constant: lineWidth),
                    ])
                }
                if x == width - 1 {
                    NSLayoutConstraint.activate([
                        self.rightAnchor.constraint(equalTo: cellView.rightAnchor, constant: lineWidth),
                    ])
                }
            }
        }
        
        for y in yRange {
            for x in xRange {
                let cellView: CellView = cellViewAt(x: x, y: y)!
                let action = CellSelectionAction(boardView: self, x: x, y: y)
                actions.append(action) // To retain the `action`
                cellView.addTarget(action, action: #selector(action.selectCell), for: .touchUpInside)
            }
        }
    }
    
    /// 盤をゲーム開始時に状態に戻します。このメソッドはアニメーションを伴いません。
    public func reset(with disks: [Disk?]) {
        animationCanceller?.cancel()
        for y in  yRange {
            for x in xRange {
                let index = y * yRange.count + x
                setDisk(disks[index], atX: x, y: y, animated: false)
            }
        }
    }
    
    private func cellViewAt(x: Int, y: Int) -> CellView? {
        guard xRange.contains(x) && yRange.contains(y) else { return nil }
        return cellViews[y * width + x]
    }
    
}

extension BoardView {
    
    private func setDisk(_ disk: Disk?, atX x: Int, y: Int, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        guard let cellView = cellViewAt(x: x, y: y) else {
            preconditionFailure() // FIXME: Add a message.
        }
        cellView.setDisk(disk, animated: animated, completion: completion)
    }
    
    private func animateSettingDisks<C: Collection>(at coordinates: C, to disk: Disk, completion: @escaping (Bool) -> Void)
        where C.Element == (Int, Int)
    {
        guard let (x, y) = coordinates.first else {
            completion(true)
            return
        }
        
        let animationCanceller = self.animationCanceller!
        setDisk(disk, atX: x, y: y, animated: true) { [weak self] finished in
            guard let self = self else { return }
            if animationCanceller.isCancelled { return }
            if finished {
                self.animateSettingDisks(at: coordinates.dropFirst(), to: disk, completion: completion)
            } else {
                for (x, y) in coordinates {
                    self.setDisk(disk, atX: x, y: y, animated: false)
                }
                completion(false)
            }
        }
    }
    
    func changeDisks(at coordinates: [(x: Int, y: Int)], to disk: Disk, animated: Bool, completion: ((Bool) -> Void)?) {
        
        if animated {
            let cleanUp: () -> Void = { [weak self] in
                self?.animationCanceller = nil
            }
            animationCanceller = Canceller(cleanUp)
            animateSettingDisks(at: coordinates, to: disk) { [weak self] finished in
                guard let self = self else { return }
                guard let canceller = self.animationCanceller else { return }
                if canceller.isCancelled { return }
                cleanUp()

                completion?(finished)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                for (x, y) in coordinates {
                    self.setDisk(disk, atX: x, y: y, animated: false)
                }
                completion?(true)
            }
        }
        
    }
    
}

public protocol BoardViewDelegate: AnyObject {
    /// `boardView` の `x`, `y` で指定されるセルがタップされたときに呼ばれます。
    /// - Parameter boardView: セルをタップされた `BoardView` インスタンスです。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    func boardView(_ boardView: BoardView, didSelectCellAtX x: Int, y: Int)
}

private class CellSelectionAction: NSObject {
    private weak var boardView: BoardView?
    let x: Int
    let y: Int
    
    init(boardView: BoardView, x: Int, y: Int) {
        self.boardView = boardView
        self.x = x
        self.y = y
    }
    
    @objc func selectCell() {
        guard let boardView = boardView else { return }
        boardView.delegate?.boardView(boardView, didSelectCellAtX: x, y: y)
    }
}
