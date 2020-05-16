import UIKit
import Combine

protocol GameEngineProtocol: AnyObject {
    
    var gameBoardWidth: Int { get }
    var gameBoardHeight: Int { get }
    
    func set(_ turn: Disk, to player: Player)
    
    func diskAt(x: Int, y: Int) -> Disk?
    func placeDiskAt(x: Int, y: Int) throws
    func nextMove()
    var isThinking: AnyPublisher<(turn: Disk, thinking: Bool), Never> { get }
    var changedDisks: AnyPublisher<(diskType: Disk, coordinates: [(x: Int, y: Int)]), Never> { get }
    
    var currentTurn: Disk? { get }
    func count(of disk: Disk) -> Int
    
    func saveGame() throws
    func loadGame() throws
    
}

class ViewController: UIViewController {
    @IBOutlet private var boardView: BoardView!
    
    @IBOutlet private var messageDiskView: DiskView!
    @IBOutlet private var messageLabel: UILabel!
    @IBOutlet private var messageDiskSizeConstraint: NSLayoutConstraint!
    private var messageDiskSize: CGFloat! // to store the size designated in the storyboard
    
    @IBOutlet private var playerControls: [UISegmentedControl]!
    @IBOutlet private var countLabels: [UILabel]!
    @IBOutlet private var playerActivityIndicators: [UIActivityIndicatorView]!
    
    let gameEngine: GameEngineProtocol = GameEngine()
    private var gameEngineCancellables: Set<AnyCancellable> = []
        
    private var animationCanceller: Canceller?
    private var isAnimating: Bool { animationCanceller != nil }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        boardView.boardSize = .init(width: gameEngine.gameBoardWidth,
                                    height: gameEngine.gameBoardHeight)
        
        boardView.delegate = self
        messageDiskSize = messageDiskSizeConstraint.constant
        
        gameEngine.isThinking.sinkInMain { [weak self] (isThinking) in
            let indicator = self?.playerActivityIndicators[isThinking.turn.index]
            if isThinking.thinking {
                indicator?.startAnimating()
            } else {
                indicator?.stopAnimating()
            }
        }.store(in: &gameEngineCancellables)
        gameEngine.changedDisks.sinkInMain { [weak self] (changedDisks) in
            self?.changeDisks(at: changedDisks.coordinates, to: changedDisks.diskType, animated: false) { [weak self] _ in
//            self?.changeDisks(at: changedDisks.coordinates, to: changedDisks.diskType, animated: true) { [weak self] _ in
                DispatchQueue.global().async {
                    self?.gameEngine.nextMove()
                }
            }
        }.store(in: &gameEngineCancellables)
        
        do {
            try loadGame()
        } catch _ {
            newGame()
        }
    }
    
    private var viewHasAppeared: Bool = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if viewHasAppeared { return }
        viewHasAppeared = true
        DispatchQueue.global().async {
            self.gameEngine.nextMove()
        }
    }
}

// MARK: Reversi logics

extension ViewController {
    func count(of disk: Disk) -> Int {
        gameEngine.count(of: disk)
    }
    
    func sideWithMoreDisks() -> Disk? {
        let darkCount = count(of: .dark)
        let lightCount = count(of: .light)
        if darkCount == lightCount {
            return nil
        } else {
            return darkCount > lightCount ? .dark : .light
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
                try? self.saveGame()
                self.updateCountLabels()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                for (x, y) in coordinates {
                    self.boardView.setDisk(disk, atX: x, y: y, animated: false)
                }
                completion?(true)
                try? self.saveGame()
                self.updateCountLabels()
            }
        }
        
    }
    
    private func animateSettingDisks<C: Collection>(at coordinates: C, to disk: Disk, completion: @escaping (Bool) -> Void)
        where C.Element == (Int, Int)
    {
        guard let (x, y) = coordinates.first else {
            completion(true)
            return
        }
        
        let animationCanceller = self.animationCanceller!
        boardView.setDisk(disk, atX: x, y: y, animated: true) { [weak self] finished in
            guard let self = self else { return }
            if animationCanceller.isCancelled { return }
            if finished {
                self.animateSettingDisks(at: coordinates.dropFirst(), to: disk, completion: completion)
            } else {
                for (x, y) in coordinates {
                    self.boardView.setDisk(disk, atX: x, y: y, animated: false)
                }
                completion(false)
            }
        }
    }
}

// MARK: Game management

extension ViewController {
    func newGame() {
        gameEngine.reset()
        boardView.reset()
        
        for playerControl in playerControls {
            playerControl.selectedSegmentIndex = Player.manual.rawValue
        }

        updateMessageViews()
        updateCountLabels()
        
        try? saveGame()
    }
    
//    func nextTurn() {
//        guard var turn = self.turn else { return }
//
//        turn.flip()
//
//        if validMoves(for: turn).isEmpty {
//            if validMoves(for: turn.flipped).isEmpty {
//                self.turn = nil
//                updateMessageViews()
//            } else {
//                self.turn = turn
//                updateMessageViews()
//
//                let alertController = UIAlertController(
//                    title: "Pass",
//                    message: "Cannot place a disk.",
//                    preferredStyle: .alert
//                )
//                alertController.addAction(UIAlertAction(title: "Dismiss", style: .default) { [weak self] _ in
//                    self?.nextTurn()
//                })
//                present(alertController, animated: true)
//            }
//        } else {
//            self.turn = turn
//            updateMessageViews()
//            waitForPlayer()
//        }
//    }
    
}

// MARK: Views

extension ViewController {
    func updateCountLabels() {
        for side in Disk.sides {
            countLabels[side.index].text = "\(count(of: side))"
        }
    }
    
    func updateMessageViews() {
        switch gameEngine.currentTurn {
        case .some(let side):
            messageDiskSizeConstraint.constant = messageDiskSize
            messageDiskView.disk = side
            messageLabel.text = "'s turn"
        case .none:
            if let winner = self.sideWithMoreDisks() {
                messageDiskSizeConstraint.constant = messageDiskSize
                messageDiskView.disk = winner
                messageLabel.text = " won"
            } else {
                messageDiskSizeConstraint.constant = 0
                messageLabel.text = "Tied"
            }
        }
    }
}

// MARK: Inputs

extension ViewController {
    @IBAction func pressResetButton(_ sender: UIButton) {
        let alertController = UIAlertController(
            title: "Confirmation",
            message: "Do you really want to reset the game?",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in })
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            self.newGame()
            DispatchQueue.global().async {
                self.gameEngine.nextMove()
            }
        })
        present(alertController, animated: true)
    }
    
    @IBAction func changePlayerControlSegment(_ sender: UISegmentedControl) {
        let side: Disk = Disk(index: playerControls.firstIndex(of: sender)!)
        
        try? saveGame()
        
        let player = Player(rawValue: sender.selectedSegmentIndex)!
        DispatchQueue.global().async {
            self.gameEngine.set(side, to: player)
        }
    }
}

extension ViewController: BoardViewDelegate {
    func boardView(_ boardView: BoardView, didSelectCellAtX x: Int, y: Int) {
        if isAnimating { return }
        DispatchQueue.global().async {
            do {
                try self.gameEngine.placeDiskAt(x: x, y: y)
                // TODO: Animating
            } catch {
                // doing nothing when an error occurs
            }
        }
    }
}

// MARK: Save and Load

extension ViewController {
    private var path: String {
        (NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("Game")
    }
    
    func saveGame() throws {
        try gameEngine.saveGame()
    }
    
    func loadGame() throws {
        try gameEngine.loadGame()
        updateMessageViews()
        updateCountLabels()
    }
    
    enum FileIOError: Error {
        case write(path: String, cause: Error?)
        case read(path: String, cause: Error?)
    }
}

// MARK: Additional types

final class Canceller {
    private(set) var isCancelled: Bool = false
    private let body: (() -> Void)?
    
    init(_ body: (() -> Void)?) {
        self.body = body
    }
    
    func cancel() {
        if isCancelled { return }
        isCancelled = true
        body?()
    }
}

struct DiskPlacementError: Error {
    let disk: Disk
    let x: Int
    let y: Int
}

// MARK: File-private extensions

extension Disk {
    init(index: Int) {
        for side in Disk.sides {
            if index == side.index {
                self = side
                return
            }
        }
        preconditionFailure("Illegal index: \(index)")
    }
    
    var index: Int {
        switch self {
        case .dark: return 0
        case .light: return 1
        }
    }
}

extension Optional where Wrapped == Disk {
    fileprivate init?<S: StringProtocol>(symbol: S) {
        switch symbol {
        case "x":
            self = .some(.dark)
        case "o":
            self = .some(.light)
        case "-":
            self = .none
        default:
            return nil
        }
    }
    
    var symbol: String {
        switch self {
        case .some(.dark):
            return "x"
        case .some(.light):
            return "o"
        case .none:
            return "-"
        }
    }
}

extension Publisher where Failure == Never {
    
    func sinkInMain(_ exec: @escaping (Output) -> Void) -> AnyCancellable {
        sink { (output) in
            DispatchQueue.main.async {
                exec(output)
            }
        }
    }
    
}
