//
//  GameSettings.swift
//  SwiftyNinja
//
//  Created by Igor Chernyshov on 04.08.2021.
//

import UIKit

struct GameSettings {

	// MARK: - Singleton
	private init() {}

	static var shared = GameSettings()

	// MARK: - Settings
	// Game
	let numberOfLives = 3
	let popupTimeReduction = 0.991
	let chainDelayReduction = 0.99
	let physicsWorldSpeedIncrease: CGFloat = 1.02
	let penguinToBombRatio = 6

	// Sequence
	let sequencePopupTime = 0.9
	let sequenceChainDelay = 3.0
	let predefinedSequence: [SequenceType] = [.oneNoBomb, .oneNoBomb, .twoWithOneBomb, .twoWithOneBomb, .three, .one, .chain]
	let firstEnemySpawnTime: DispatchTime = .now() + 2

	// World
	let physicsWorldSpeed: CGFloat = 0.85
	let worldBottom: CGFloat = -140
}
