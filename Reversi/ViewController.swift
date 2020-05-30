import UIKit
import Combine

protocol GameEngineProtocol: AnyObject {
    
    var gameBoardWidth: Int { get }
    var gameBoardHeight: Int { get }
    
    func reset()
    
    func setPlayer(_ player: Player, for turn: Disk)
    func getPlayer(for turn: Disk) -> Player
    
    func placeDiskAt(x: Int, y: Int)
    func nextMove()
    var isThinking: AnyPublisher<(turn: Disk, thinking: Bool), Never> { get }
    var changedDisks: AnyPublisher<(diskType: Disk, coordinates: [(x: Int, y: Int)]), Never> { get }
    
    var currentBoard: [Disk?] { get }
    var currentTurn: AnyPublisher<Turn, Never> { get }
    func currentCount(of disk: Disk) -> AnyPublisher<Int, Never>
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        boardView.boardSize = .init(width: gameEngine.gameBoardWidth,
                                    height: gameEngine.gameBoardHeight)
        
        boardView.delegate = self
        messageDiskSize = messageDiskSizeConstraint.constant
        
        gameEngine.currentTurn.sink(in: .main) { [weak self] (turn) in
            self?.updateMessageViews(accordingTo: turn)
        }.store(in: &gameEngineCancellables)
        Disk.sides.forEach { (side) in
            gameEngine.currentCount(of: side).sink(in: .main) { [weak self] (count) in
                self?.updateCountLabels(side: side, count: count)
            }.store(in: &gameEngineCancellables)
        }
        gameEngine.isThinking.sink(in: .main) { [weak self] (isThinking) in
            let indicator = self?.playerActivityIndicators[isThinking.turn.index]
            if isThinking.thinking {
                indicator?.startAnimating()
            } else {
                indicator?.stopAnimating()
            }
        }.store(in: &gameEngineCancellables)
        gameEngine.changedDisks.sink(in: .main) { [weak self] (changedDisks) in
            self?.changeDisks(at: changedDisks.coordinates, to: changedDisks.diskType, animated: true) { [weak self] _ in
                self?.gameEngine.nextMove()
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
        gameEngine.nextMove()
    }
}

// MARK: Reversi logics

extension ViewController {
    
    func changeDisks(at coordinates: [(x: Int, y: Int)], to disk: Disk, animated: Bool, completion: ((Bool) -> Void)?) {
        
        boardView.changeDisks(at: coordinates, to: disk, animated: animated) { [weak self] finished in
            try? self?.saveGame()
            completion?(finished)
        }
        
    }
    
}

// MARK: Game management

extension ViewController {
    func newGame() {
        gameEngine.reset()
        boardView.reset(with: gameEngine.currentBoard)
        
        for (index, playerControl) in playerControls.enumerated() {
            let side: Disk = Disk(index: index)
            playerControl.selectedSegmentIndex = gameEngine.getPlayer(for: side).rawValue
        }
        
        try? saveGame()
    }
    
}

// MARK: Views

extension ViewController {
    func updateCountLabels(side: Disk, count: Int) {
        countLabels[side.index].text = "\(count)"
    }
    
    func updateMessageViews(accordingTo turn: Turn) {
        switch turn {
        case .validTurn(let side):
            messageDiskSizeConstraint.constant = messageDiskSize
            messageDiskView.disk = side
            messageLabel.text = "'s turn"
            
        case .skippingTurn:
            let alertController = UIAlertController(
                title: "Pass",
                message: "Cannot place a disk.",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "Dismiss", style: .default) { [weak self] _ in
                self?.gameEngine.nextMove()
            })
            present(alertController, animated: true)
            
        case .finished(winner: let winner):
            if let winner = winner {
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
            self.gameEngine.nextMove()
        })
        present(alertController, animated: true)
    }
    
    @IBAction func changePlayerControlSegment(_ sender: UISegmentedControl) {
        let side: Disk = Disk(index: playerControls.firstIndex(of: sender)!)
        
        try? saveGame()
        
        let player = Player(rawValue: sender.selectedSegmentIndex)!
        self.gameEngine.setPlayer(player, for: side)
        self.gameEngine.nextMove()
    }
}

extension ViewController: BoardViewDelegate {
    func boardView(_ boardView: BoardView, didSelectCellAtX x: Int, y: Int) {
        if boardView.isAnimating { return }
        gameEngine.placeDiskAt(x: x, y: y)
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
        boardView.reset(with: gameEngine.currentBoard)
    }
    
    enum FileIOError: Error {
        case write(path: String, cause: Error?)
        case read(path: String, cause: Error?)
    }
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

extension Publisher where Failure == Never {
    
    func sink(in queue: DispatchQueue, _ exec: @escaping (Output) -> Void) -> AnyCancellable {
        receive(on: queue).sink { (output) in
            exec(output)
        }
    }
    
}
