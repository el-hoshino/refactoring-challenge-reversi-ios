import UIKit
import Combine

protocol GameEngineProtocol: AnyObject {
    
    var gameBoardWidth: Int { get }
    var gameBoardHeight: Int { get }
    
    func diskAt(x: Int, y: Int) -> Disk?
    func placeDiskAt(x: Int, y: Int) throws
    var changedDisks: AnyPublisher<(diskType: Disk, coordinates: [(x: Int, y: Int)]), Never> { get }
    
    func count(of disk: Disk) -> Int
    func validMoves(for side: Disk) -> [(x: Int, y: Int)]
    
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
    
    private var turn: Disk? = .dark // `nil` if the current game is over
    
    private var animationCanceller: Canceller?
    private var isAnimating: Bool { animationCanceller != nil }
    
    private var playerCancellers: [Disk: Canceller] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        boardView.boardSize = .init(width: gameEngine.gameBoardWidth,
                                    height: gameEngine.gameBoardHeight)
        
        boardView.delegate = self
        messageDiskSize = messageDiskSizeConstraint.constant
        
        gameEngine.changedDisks.sink { [weak self] (changedDisks) in
            self?.changeDisks(at: changedDisks.coordinates, to: changedDisks.diskType, animated: true) { [weak self] _ in
                self?.waitForPlayer()
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
        waitForPlayer()
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
    
    func validMoves(for side: Disk) -> [(x: Int, y: Int)] {
        gameEngine.validMoves(for: side)
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
        boardView.reset()
        turn = .dark
        
        for playerControl in playerControls {
            playerControl.selectedSegmentIndex = Player.manual.rawValue
        }

        updateMessageViews()
        updateCountLabels()
        
        try? saveGame()
    }
    
    func waitForPlayer() {
        guard let turn = self.turn else { return }
        switch Player(rawValue: playerControls[turn.index].selectedSegmentIndex)! {
        case .manual:
            break
        case .computer:
            playTurnOfComputer()
        }
    }
    
    func nextTurn() {
        guard var turn = self.turn else { return }

        turn.flip()
        
        if validMoves(for: turn).isEmpty {
            if validMoves(for: turn.flipped).isEmpty {
                self.turn = nil
                updateMessageViews()
            } else {
                self.turn = turn
                updateMessageViews()
                
                let alertController = UIAlertController(
                    title: "Pass",
                    message: "Cannot place a disk.",
                    preferredStyle: .alert
                )
                alertController.addAction(UIAlertAction(title: "Dismiss", style: .default) { [weak self] _ in
                    self?.nextTurn()
                })
                present(alertController, animated: true)
            }
        } else {
            self.turn = turn
            updateMessageViews()
            waitForPlayer()
        }
    }
    
    func playTurnOfComputer() {
        guard let turn = self.turn else { preconditionFailure() }
        let (x, y) = validMoves(for: turn).randomElement()!

        playerActivityIndicators[turn.index].startAnimating()
        
        let cleanUp: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.playerActivityIndicators[turn.index].stopAnimating()
            self.playerCancellers[turn] = nil
        }
        let canceller = Canceller(cleanUp)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            if canceller.isCancelled { return }
            cleanUp()
            
            try! self.gameEngine.placeDiskAt(x: x, y: y)
        }
        
        playerCancellers[turn] = canceller
    }
}

// MARK: Views

extension ViewController {
    func updateCountLabels() {
        for side in Disk.sides {
            countLabels[side.index].text = "\(count(of: side))"
        }
    }
    
    func updateMessageViews() {
        switch turn {
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
            
            self.animationCanceller?.cancel()
            self.animationCanceller = nil
            
            for side in Disk.sides {
                self.playerCancellers[side]?.cancel()
                self.playerCancellers.removeValue(forKey: side)
            }
            
            self.newGame()
            self.waitForPlayer()
        })
        present(alertController, animated: true)
    }
    
    @IBAction func changePlayerControlSegment(_ sender: UISegmentedControl) {
        let side: Disk = Disk(index: playerControls.firstIndex(of: sender)!)
        
        try? saveGame()
        
        if let canceller = playerCancellers[side] {
            canceller.cancel()
        }
        
        if !isAnimating, side == turn, case .computer = Player(rawValue: sender.selectedSegmentIndex)! {
            playTurnOfComputer()
        }
    }
}

extension ViewController: BoardViewDelegate {
    func boardView(_ boardView: BoardView, didSelectCellAtX x: Int, y: Int) {
        if isAnimating { return }
        do {
            try gameEngine.placeDiskAt(x: x, y: y)
            // TODO: Animating
        } catch {
            // doing nothing when an error occurs
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
