//
//  GameScene.swift
//  SwiftyNinja
//
//  Created by Igor Chernyshov on 02.08.2021.
//

import SpriteKit
import GameplayKit
import AVFoundation

final class GameScene: SKScene {

	// MARK: - Properties
	// Game Configuration
	private var isGameEnded = false
	private var settings = GameSettings.shared

	// User Stats
	private lazy var lives = settings.numberOfLives
	private var score = 0 {
		didSet {
			gameScore.text = "Score: \(score)"
		}
	}

	// Labels
	private var gameScore: SKLabelNode!
	private var livesImages = [SKSpriteNode]()
	private var gameOverNode: SKLabelNode!

	// Slice
	private var activeSlicePoints = [CGPoint]()
	private var activeSliceBG: SKShapeNode!
	private var activeSliceFG: SKShapeNode!
	private var activeSlices: [SKShapeNode] { [activeSliceBG, activeSliceFG] }

	// Enemies
	private var activeEnemies = [SKSpriteNode]()

	// Sound Effects
	private var isSwooshSoundActive = false
	private var bombSoundEffect: AVAudioPlayer?

	// Sequence
	private lazy var popupTime = settings.sequencePopupTime
	private var sequence = [SequenceType]()
	private var sequencePosition = 0
	private lazy var chainDelay = settings.sequenceChainDelay
	private var nextSequenceQueued = true

	// MARK: - Lifecycle
    override func didMove(to view: SKView) {
		let background = SKSpriteNode(imageNamed: "sliceBackground")
		background.position = CGPoint(x: 512, y: 384)
		background.blendMode = .replace
		background.zPosition = -1
		addChild(background)

		physicsWorld.gravity = CGVector(dx: 0, dy: -6)
		physicsWorld.speed = settings.physicsWorldSpeed

		createScore()
		createLives()
		createSlices()

		sequence = settings.predefinedSequence

		for _ in 0...1000 {
			if let nextSequence = SequenceType.allCases.randomElement() {
				sequence.append(nextSequence)
			}
		}

		DispatchQueue.main.asyncAfter(deadline: settings.firstEnemySpawnTime) { [weak self] in
			self?.tossEnemies()
		}
    }

	override func update(_ currentTime: TimeInterval) {
		var bombCount = 0

		for node in activeEnemies {
			if node.name == "bombContainer" {
				bombCount += 1
				break
			}
		}

		if bombCount == 0 {
			bombSoundEffect?.stop()
			bombSoundEffect = nil
		}

		if activeEnemies.count > 0 {
			for (index, node) in activeEnemies.enumerated().reversed() {
				if node.position.y < settings.worldBottom {
					node.removeAllActions()

					if node.name == "enemy" || node.name == "fastEnemy" {
						node.name = ""
						subtractLife()

						node.removeFromParent()
						activeEnemies.remove(at: index)
					} else if node.name == "bombContainer" {
						node.name = ""
						node.removeFromParent()
						activeEnemies.remove(at: index)
					}
				}
			}
		} else {
			if !nextSequenceQueued {
				DispatchQueue.main.asyncAfter(deadline: .now() + popupTime) { [weak self] in
					self?.tossEnemies()
				}

				nextSequenceQueued = true
			}
		}
	}

	// MARK: - Nodes Creation
	private func createScore() {
		gameScore = SKLabelNode(fontNamed: "Chalkduster")
		gameScore.horizontalAlignmentMode = .left
		gameScore.fontSize = 48
		addChild(gameScore)

		gameScore.position = CGPoint(x: 8, y: 8)
		score = 0
	}

	private func createLives() {
		(0..<settings.numberOfLives).forEach {
			let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
			spriteNode.position = CGPoint(x: CGFloat(834 + ($0 * 70)), y: 720)
			addChild(spriteNode)

			livesImages.append(spriteNode)
		}
	}

	private func createGameOverNode() {
		gameOverNode = SKLabelNode(fontNamed: "Chalkduster")
		gameOverNode.horizontalAlignmentMode = .center
		gameOverNode.position = CGPoint(x: 512, y: 384)
		gameOverNode.fontSize = 36
		gameOverNode.text = "Game Over"
		gameOverNode.zPosition = 4
		addChild(gameOverNode)
		gameOverNode.run(SKAction.scale(to: 1.3, duration:1))
	}

	private func createSlices() {
		activeSliceBG = SKShapeNode()
		activeSliceBG.zPosition = 2
		activeSliceBG.strokeColor = UIColor(red: 1, green: 0.9, blue: 0, alpha: 1)
		activeSliceBG.lineWidth = 9
		addChild(activeSliceBG)

		activeSliceFG = SKShapeNode()
		activeSliceFG.zPosition = 3
		activeSliceFG.strokeColor = UIColor.white
		activeSliceFG.lineWidth = 5
		addChild(activeSliceFG)
	}

	// MARK: - Touches Processing
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let touch = touches.first else { return }

		activeSlicePoints.removeAll(keepingCapacity: true)
		let location = touch.location(in: self)
		activeSlicePoints.append(location)
		redrawActiveSlice()
		activeSlices.forEach {
			$0.removeAllActions()
			$0.alpha = 1
		}
	}

	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		if isGameEnded { return }
		guard let touch = touches.first else { return }

		let location = touch.location(in: self)
		activeSlicePoints.append(location)
		redrawActiveSlice()

		if !isSwooshSoundActive { playSwooshSound() }

		let nodesAtPoint = nodes(at: location)

		for case let node as SKSpriteNode in nodesAtPoint {
			if node.name == "enemy" || node.name == "fastEnemy" {
				if let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy") {
					emitter.position = node.position
					addChild(emitter)
				}

				score += node.name == "enemy" ? 1 : 3

				node.name = ""
				node.physicsBody?.isDynamic = false

				let scaleOut = SKAction.scale(to: 0.001, duration:0.2)
				let fadeOut = SKAction.fadeOut(withDuration: 0.2)
				let group = SKAction.group([scaleOut, fadeOut])
				let sequence = SKAction.sequence([group, .removeFromParent()])
				node.run(sequence)

				if let index = activeEnemies.firstIndex(of: node) {
					activeEnemies.remove(at: index)
				}

				run(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))
			} else if node.name == "bomb" {
				guard let bombContainer = node.parent as? SKSpriteNode else { continue }

				if let emitter = SKEmitterNode(fileNamed: "sliceHitBomb") {
					emitter.position = bombContainer.position
					addChild(emitter)
				}
				node.name = ""
				bombContainer.physicsBody?.isDynamic = false

				let scaleOut = SKAction.scale(to: 0.001, duration:0.2)
				let fadeOut = SKAction.fadeOut(withDuration: 0.2)
				let group = SKAction.group([scaleOut, fadeOut])
				let sequence = SKAction.sequence([group, .removeFromParent()])
				bombContainer.run(sequence)

				if let index = activeEnemies.firstIndex(of: bombContainer) {
					activeEnemies.remove(at: index)
				}

				run(SKAction.playSoundFileNamed("explosion.caf", waitForCompletion: false))
				endGame(triggeredByBomb: true)
			}
		}
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		activeSlices.forEach { $0.run(SKAction.fadeOut(withDuration: 0.25)) }
	}

	// MARK: - Game Logic
	private func redrawActiveSlice() {
		guard activeSlicePoints.count > 1 else {
			activeSlices.forEach { $0.path = nil }
			return
		}

		if activeSlicePoints.count > 12 {
			activeSlicePoints.removeFirst(activeSlicePoints.count - 12)
		}

		let path = UIBezierPath()
		path.move(to: activeSlicePoints[0])

		(1..<activeSlicePoints.count).forEach {
			path.addLine(to: activeSlicePoints[$0])
		}

		activeSliceBG.path = path.cgPath
		activeSliceFG.path = path.cgPath
	}

	private func playSwooshSound() {
		isSwooshSoundActive = true

		let randomNumber = Int.random(in: 1...3)
		let soundName = "swoosh\(randomNumber).caf"

		let swooshSound = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)

		run(swooshSound) { [weak self] in
			self?.isSwooshSoundActive = false
		}
	}

	private func createEnemy(forceBomb: ForceBomb = .random) {
		let enemy: SKSpriteNode

		let enemyType: Int
		switch forceBomb {
		case .always: enemyType = 0
		case .never: enemyType = Int.random(in: 1...settings.penguinToBombRatio)
		case .random: enemyType = Int.random(in: 0...settings.penguinToBombRatio)
		}

		if enemyType == 0 {
			enemy = SKSpriteNode()
			enemy.zPosition = 1
			enemy.name = "bombContainer"

			let bombImage = SKSpriteNode(imageNamed: "sliceBomb")
			bombImage.name = "bomb"
			enemy.addChild(bombImage)

			if bombSoundEffect != nil {
				bombSoundEffect?.stop()
				bombSoundEffect = nil
			}

			if let path = Bundle.main.url(forResource: "sliceBombFuse", withExtension: "caf"),
			   let sound = try? AVAudioPlayer(contentsOf: path) {
				bombSoundEffect = sound
				sound.play()
			}

			if let emitter = SKEmitterNode(fileNamed: "sliceFuse") {
				emitter.position = CGPoint(x: 76, y: 64)
				enemy.addChild(emitter)
			}
		} else if enemyType == 1 {
			enemy = SKSpriteNode(imageNamed: "penguin")
			enemy.color = .red
			enemy.colorBlendFactor = 0.7
			run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
			enemy.name = "fastEnemy"
		} else {
			enemy = SKSpriteNode(imageNamed: "penguin")
			run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
			enemy.name = "enemy"
		}

		let randomPosition = CGPoint(x: Int.random(in: 64...960), y: -128)
		enemy.position = randomPosition

		let randomAngularVelocity = CGFloat.random(in: -3...3)
		var randomXVelocity: Int

		if randomPosition.x < 256 {
			randomXVelocity = Int.random(in: 8...15)
		} else if randomPosition.x < 512 {
			randomXVelocity = Int.random(in: 3...5)
		} else if randomPosition.x < 768 {
			randomXVelocity = -Int.random(in: 3...5)
		} else {
			randomXVelocity = -Int.random(in: 8...15)
		}

		var randomYVelocity = Int.random(in: 24...32)

		let velocityMultiplier: Int
		if enemyType == 1 {
			velocityMultiplier = 50
		} else {
			velocityMultiplier = 40
		}
		randomXVelocity *= velocityMultiplier
		randomYVelocity *= velocityMultiplier

		enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64)
		enemy.physicsBody?.velocity = CGVector(dx: randomXVelocity, dy: randomYVelocity)
		enemy.physicsBody?.angularVelocity = randomAngularVelocity
		enemy.physicsBody?.collisionBitMask = 0

		addChild(enemy)
		activeEnemies.append(enemy)
	}

	private func tossEnemies() {
		if isGameEnded { return }
		popupTime *= settings.popupTimeReduction
		chainDelay *= settings.chainDelayReduction
		physicsWorld.speed *= settings.physicsWorldSpeedIncrease

		let sequenceType = sequence[sequencePosition]

		switch sequenceType {
		case .oneNoBomb:
			createEnemy(forceBomb: .never)
		case .one:
			createEnemy()
		case .twoWithOneBomb:
			createEnemy(forceBomb: .never)
			createEnemy(forceBomb: .always)
		case .two:
			createEnemy()
			createEnemy()
		case .three:
			createEnemy()
			createEnemy()
			createEnemy()
		case .four:
			createEnemy()
			createEnemy()
			createEnemy()
			createEnemy()
		case .chain:
			createEnemy()
			DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0)) { [weak self] in self?.createEnemy() }
			DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 2)) { [weak self] in self?.createEnemy() }
			DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 3)) { [weak self] in self?.createEnemy() }
			DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 4)) { [weak self] in self?.createEnemy() }

		case .fastChain:
			createEnemy()
			DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0)) { [weak self] in self?.createEnemy() }
			DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 2)) { [weak self] in self?.createEnemy() }
			DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 3)) { [weak self] in self?.createEnemy() }
			DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 4)) { [weak self] in self?.createEnemy() }
		}

		sequencePosition += 1
		nextSequenceQueued = false
	}

	private func subtractLife() {
		lives -= 1

		run(SKAction.playSoundFileNamed("wrong.caf", waitForCompletion: false))

		var life: SKSpriteNode

		if lives == 2 {
			life = livesImages[0]
		} else if lives == 1 {
			life = livesImages[1]
		} else {
			life = livesImages[2]
			endGame(triggeredByBomb: false)
		}

		life.texture = SKTexture(imageNamed: "sliceLifeGone")

		life.xScale = 1.3
		life.yScale = 1.3
		life.run(SKAction.scale(to: 1, duration:0.1))
	}

	private func endGame(triggeredByBomb: Bool) {
		if isGameEnded { return }

		isGameEnded = true
		physicsWorld.speed = 0
		isUserInteractionEnabled = false

		createGameOverNode()

		bombSoundEffect?.stop()
		bombSoundEffect = nil

		if triggeredByBomb {
			livesImages.forEach { $0.texture = SKTexture(imageNamed: "sliceLifeGone") }
		}
	}
}
