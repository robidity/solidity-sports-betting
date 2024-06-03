// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interface/ILiquidityV1.sol";
import "./interface/IWelcomeBonusV1.sol";
import "./interface/IBonusV1.sol";
import "./interface/IAffiliateV1.sol";
import "./TokenTransferV1.sol";

/**
 * @author BetcoinPro
 * @title  Core smart contract
 * @notice Core contract to manage games, markets, bets and payouts.
 * 		   The contract allows to add games, edit games, add markets to games,
 * 		   edit markets and put bets.
 * 		   It also allows to pay won bets to the users by using the payWonBet function,
 * 		   which in turn uses Liquidity and TokenTransfer contracts.
 */

contract CoreV1 is UUPSUpgradeable, OwnableUpgradeable {
	struct Game {
		string ipfsHash;
		uint64 sportId;
		uint256 startsAt;
		string status;
		bool resolved;
		bool enabled;
	}

	struct Market {
		uint256 marketId;
		uint64 [] odds;
		uint64 [] outcomesIds;
		uint64 [] resolvedOutcome;
		bool enabled;
	}
	
	struct Bet {
		uint256 sportId;
		uint256 gameId;
		uint256 marketId;
		uint256 amount;
		uint64 odd;
		uint64 outcomeWinId;
	}
	
	struct BetsSet {
		uint256 amount;
		bool paid;
		uint256 createdAt;
		bool welcomeBonusApplied;
		uint256 bettorBonusAmount;
	}
	
	modifier onlyManager() {
        require(managers[0] == msg.sender || managers[1] == msg.sender
		|| managers[2] == msg.sender, "Core: Not manager");
        _;
    }
	
	modifier onlyOracle() {
		require(msg.sender == oracleAddress, "Core: You are not allowed");
		_;
	}

	event AddGame(uint256 indexed gameId);
	event EditGame(uint256 indexed gameId);
	event AddMarketsToGame(uint256 indexed gameId);
	event EditGameMarkets(uint256 indexed gameId);
	event PutBets(
		uint256 indexed betsSetsId,
		address indexed sender,
		uint256 paidAmount,
		address indexed referral,
		uint256 referralReward,
		bool welcomeBonusApplied,
		uint256 bettorBonusAmount
	);
	event PayWonBet(
		uint256 indexed betsSetId,
		address sender,
		uint256 totalOutcomeAmount,
		bool welcomeBonusApplied,
		bool bonusApplied
	);
	
	mapping(address => uint256[]) private usersBetsSets;
	mapping(uint256 => BetsSet) private betsSets;
	mapping(uint256 => uint256[]) private betsMapping;
	mapping(uint256 => Bet) private bets;
	mapping(uint256 => Game) private games;
	mapping(uint256 => Market[]) private gameMarkets;
	mapping(address => uint256[]) private unpaidBetsSets;
	mapping(uint256 => uint256[]) private _gamesByDate;
	mapping(address => uint256) private _userBetsCount;
	string[] private sports;

	ERC20 private tokenContract;
	uint8 private tokenDecimals;

	uint256 private minimumSingleBetAmount;
	uint256 private minimumComboBetAmount;
	uint256 public oddsDecimals;
	bool public allowLiveBets;
	
	mapping(uint8 => address) public managers;

	address public oracleAddress;
	address public liquidityAddress;
	address public welcomeBonusAddress;
	address public bonusAddress;
	address public affiliateAddress;
	ILiquidityV1 private liquidityContract;
	IWelcomeBonusV1 private welcomeBonusContract;
	IBonusV1 private bonusContract;
	IAffiliateV1 private affiliateContract;

	uint256 private _lastGameId;
	uint256 private _lastBetId;
	uint256 private _lastBetsSetId;
	
	function initialize(address _liquidityAddress, address _tokenAddress)
	public initializer {
		__Ownable_init();
		__UUPSUpgradeable_init();

		liquidityAddress = _liquidityAddress;
		liquidityContract = ILiquidityV1(_liquidityAddress);
		
		tokenContract = ERC20(_tokenAddress);
		tokenDecimals = tokenContract.decimals();
		
		minimumSingleBetAmount = 5*(10 ** (tokenDecimals-1)); //0.5
		minimumComboBetAmount = 5*(10 ** (tokenDecimals-1)); //0.5
		oddsDecimals = 2;
		
		managers[0] = msg.sender;
	}
	
	function _authorizeUpgrade(address) internal override onlyOwner {}

	/**
	 * @dev Add a game to _gamesByDate for a given date.
	 * @param _date The date of the game at midnight in unix timestamp format
	 * @param _gameIndex The index of the game in the games mapping
	 */
	function _setGameByDate(uint256 _date, uint256 _gameIndex) private {
		_gamesByDate[_date].push(_gameIndex);
	}

	/**
	 * @dev Get games by date.
	 * @param _date The date of the game at midnight in unix timestamp format
	 */
	function getGamesByDate(uint256 _date) public view returns (uint256[] memory) {
		return _gamesByDate[_date];
	}
	
	/**
	 * @dev Add a game to smart contract.
	 * @param _gameArray The game data
	 * @param _gameMarketsArray The markets data
	 * @param _date The date of the game at midnight in unix timestamp format
	 */
	function addGame(
		Game memory _gameArray,
		Market[] memory _gameMarketsArray,
		uint256 _date
	) public onlyOracle returns (uint256) {
		bool _resolved = false;
		bool _enabled = true;
		uint256 _gameId = _incrementLastGameId();
		games[_gameId] = Game(
			_gameArray.ipfsHash,
			_gameArray.sportId,
			_gameArray.startsAt,
			_gameArray.status,
			_resolved,
			_enabled
		);
		_setGameByDate(_date, _gameId);

		for(uint i = 0; i<_gameMarketsArray.length; i++){
			gameMarkets[_gameId].push(
				Market(
					_gameMarketsArray[i].marketId,
					_gameMarketsArray[i].odds,
					_gameMarketsArray[i].outcomesIds,
					_gameMarketsArray[i].resolvedOutcome,
					_gameMarketsArray[i].enabled
				)
			);
		}

		emit AddGame(_gameId);
		return _gameId;
	}
	
	/**
	 * @dev Edit a game.
	 * @param _gameId The game id
	 * @param _game The game data
	 * @param _date The date of the game at midnight in unix timestamp format
	 */
	function editGame(uint256 _gameId, Game calldata _game, uint256 _date)
	public onlyOracle {
		if(games[_gameId].startsAt != _game.startsAt){
			_setGameByDate(_date, _gameId);
		}

		games[_gameId] = _game;
		emit EditGame(_gameId);
	}

	/**
	 * @dev Get a game by id.
	 * @param _id The game id
	 */
	function getGameById(uint256 _id) public view returns (Game memory) {
		return (games[_id]);
	}

	/**
	 * @dev Add markets to a game.
	 * @param _gameId The game id
	 * @param _gameMarketsArray The markets data
	 */
	function addMarketsToGame(uint256 _gameId, Market[] memory _gameMarketsArray)
	public onlyOracle {
		for(uint i = 0; i<_gameMarketsArray.length; i++){
			gameMarkets[_gameId].push(
				Market(
					_gameMarketsArray[i].marketId,
					_gameMarketsArray[i].odds,
					_gameMarketsArray[i].outcomesIds,
					_gameMarketsArray[i].resolvedOutcome,
					_gameMarketsArray[i].enabled
				)
			);
		}

		emit AddMarketsToGame(_gameId);
	}

	/**
	 * @dev Edit markets of a game.
	 * @param _gameId The game id
	 * @param _markets The markets data
	 */
	function editGameMarkets(
		uint256 _gameId,
		Market[] memory _markets
	) external onlyOracle {
		for (uint i=0; i<gameMarkets[_gameId].length; i++) {
			for (uint j=0; j<_markets.length; j++) {
				if (gameMarkets[_gameId][i].marketId == _markets[j].marketId) {
					gameMarkets[_gameId][i] = _markets[j];
				}
			}
		}

		emit EditGameMarkets(_gameId);
	}

	/**
	 * @dev Get markets of a game.
	 * @param _gameId The game id
	 */
	function getGameMarkets(uint256 _gameId)
	public view returns (Market[] memory) {
		return (gameMarkets[_gameId]);
	}
	
	/**
	 * @dev Set if a game is enabled or not.
	 * @param _gameId The game id
	 * @param _enabled The game status
	 */
	function setGameEnabled(uint256 _gameId, bool _enabled) public onlyOracle {
		games[_gameId].enabled = _enabled;
	}
	
	/**
	 * @dev Allow a bettor to put bets.
	 * @param _newBets The bets data
	 * @param _isCombo If the bets are a combo
	 * @param _paidAmount The total amount paid for the bets
	 * @param _referral The referral address
	 * @param _referred The referred address
	 * @param _welcomeBonusApplied If the welcome bonus is applied
	 * @param _bonusApplied If the bonus is applied
	 */
	function putBets(
		Bet[] calldata _newBets,
		bool _isCombo,
		uint256 _paidAmount,
		address _referral,
		address _referred,
		bool _welcomeBonusApplied,
		bool _bonusApplied
	) public returns (bool) {
		uint256 _totalBetsAmount = 0;
		bool _paid = false;
		uint256 _nextBetsSetId;
		uint256 _nextBetId;
		uint256 _betsSetsId = 0;
		uint64 _coreOdd;
		uint256 _coreOddWithDecimals;
		bool isUserApplicableForWelcomeBonus = false;
		bool isUserApplicableForBonus = false;
		uint256 _bettorBonusAmount = 0;
		uint256 _referralReward = 0;
		Market[] storage _markets;
		TokenTransferV1 tokenTransferContract;

		require(liquidityContract.balance() >= _paidAmount,
		"Core: Insufficient contract balance. Amount should be lower");
		
		if (address(welcomeBonusContract) != address(0)
		&& welcomeBonusContract.isUserApplicableForBonus(msg.sender)
		&& (getUserBetsCount(msg.sender) == 0
			|| welcomeBonusContract.didBettorEnjoyWelcomeBonusOnSuspendedGame(msg.sender))
		) {
			require(_isCombo || !_isCombo && _newBets.length == 1,
			"Core: You can only enjoy welcome bonus for a combo or single bet");
			isUserApplicableForWelcomeBonus = true;
		}

		if (address(bonusContract) != address(0)
		&& bonusContract.isUserApplicableForBonus(msg.sender)
		&& bonusContract.getBettorBonus(msg.sender) == _paidAmount
		&& _bonusApplied) {
			isUserApplicableForBonus = true;
			_bettorBonusAmount = bonusContract.getBettorBonus(msg.sender);
		}
		
		require(liquidityContract.payForBet(msg.sender, _paidAmount, isUserApplicableForBonus),
		"Core: Payment couldn't be made");

		for (uint i = 0; i < _newBets.length; i++) {
			require((games[_newBets[i].gameId].startsAt > block.timestamp) || allowLiveBets, "Core: Game has started");
			require(games[_newBets[i].gameId].enabled && !games[_newBets[i].gameId].resolved,
			"Core: Game is disabled or over");
			_markets = gameMarkets[_newBets[i].gameId];

			for (uint j = 0; j < _markets.length; j++) {
				if (_markets[j].marketId == _newBets[i].marketId) {
					require(_markets[j].enabled, "Core: Market is disabled");
					_coreOdd = _markets[j].odds[_newBets[i].outcomeWinId];
					if (isUserApplicableForWelcomeBonus && _welcomeBonusApplied) {
						_coreOddWithDecimals = _coreOdd*(10**(tokenDecimals-oddsDecimals));
						welcomeBonusContract.betMeetsRequirements(
							_paidAmount,
							_coreOddWithDecimals
						);
					}
					break;
				}
			}

			if (_isCombo) {
				if (i==0) {
					require(_paidAmount >= minimumComboBetAmount,
					"Core: Wrong combo amount. Amount should be higher");
					_nextBetsSetId = _incrementLastBetsSetId();
					betsSets[_nextBetsSetId] = BetsSet(
						_paidAmount,
						_paid,
						block.timestamp,
						isUserApplicableForWelcomeBonus && _welcomeBonusApplied,
						_bettorBonusAmount
					);
					unpaidBetsSets[msg.sender].push(_nextBetsSetId);
					usersBetsSets[msg.sender].push(_nextBetsSetId);

					emit PutBets(
						_nextBetsSetId,
						msg.sender,
						_paidAmount,
						_referral,
						_referralReward,
						isUserApplicableForWelcomeBonus && _welcomeBonusApplied,
						_bettorBonusAmount
					);
				}
				_nextBetId = _incrementLastBetId();
				bets[_nextBetId] = Bet(
					_newBets[i].sportId,
					_newBets[i].gameId,
					_newBets[i].marketId,
					0,
					_coreOdd,
					_newBets[i].outcomeWinId
				);
				betsMapping[_nextBetsSetId].push(_nextBetId);
				_betsSetsId = _nextBetsSetId;
			} else {
				require(_newBets[i].amount >= minimumSingleBetAmount,
				"Core: Wrong bet amount. Amount should be higher");
				_nextBetsSetId = _incrementLastBetsSetId();
				_nextBetId = _incrementLastBetId();
				bets[_nextBetId] = Bet(
					_newBets[i].sportId,
					_newBets[i].gameId,
					_newBets[i].marketId,
					_newBets[i].amount,
					_coreOdd,
					_newBets[i].outcomeWinId
				);
				betsMapping[_nextBetsSetId].push(_nextBetId);
				betsSets[_nextBetsSetId] = BetsSet(
					_newBets[i].amount,
					_paid,
					block.timestamp,
					isUserApplicableForWelcomeBonus && _welcomeBonusApplied,
					_bettorBonusAmount
				);

				emit PutBets(
					_nextBetsSetId,
					msg.sender,
					_paidAmount,
					_referral,
					_referralReward,
					isUserApplicableForWelcomeBonus && _welcomeBonusApplied,
					_bettorBonusAmount
				);

				_bettorBonusAmount = 0;
				_totalBetsAmount += _newBets[i].amount;
				unpaidBetsSets[msg.sender].push(_nextBetsSetId);
				usersBetsSets[msg.sender].push(_nextBetsSetId);
				_betsSetsId = _nextBetsSetId;
			}
		}

		require(_paidAmount >= _totalBetsAmount, "Core: Wrong bet amounts");
		
		if (isUserApplicableForWelcomeBonus && _welcomeBonusApplied) {
			welcomeBonusContract.setBettorEnjoyedWelcomeBonus(msg.sender, true);
			welcomeBonusContract.setBettorEnjoyedWelcomeBonusOnSuspendedGame(msg.sender, false);
		}
		
		if (isUserApplicableForBonus && _bonusApplied) {
			bonusContract.setBettorBonus(msg.sender, 0);
		}

		if (_referral != address(0)
		&& _referred != address(0)
		&& address(affiliateContract) != address(0)
		&& affiliateContract.isWhitelistEnabled()
		&& affiliateContract.isWhitelisted(_referral)) {
			_referralReward = affiliateContract.amountToPayReferral(
				_referral,
				_paidAmount
			);
			require(_createUserTokenTransferContract(_referral),
			"Core: Error creating token transfer contract");
			tokenTransferContract = TokenTransferV1(
				liquidityContract.getUserTokenTransferContract(_referral)
			);
			require(tokenTransferContract.withdrawTokens(
				_referral,
				_referralReward
			), "Core: Withdraw to referral couldn't be made");
			require(affiliateContract.addRewardInfoToReferral(
				_referral,
				_referred,
				_betsSetsId,
				_referralReward
			));
		}
		_incrementUserBetsCount(msg.sender);

		return (true);
	}
	
	/**
	 * @dev Add a sport.
	 * @param _name The sport name
	 */
	function addSport(string memory _name) public onlyManager returns (bool) {
		sports.push(_name);
		return true;
	}

	/**
	 * @dev Get a sport by id.
	 * @param _id The sport id
	 */
	function getSport(uint256 _id) public view returns (string memory) {
		return sports[_id];
	}

	/**
	 * @dev Get all sports.
	 */
	function getSports() public view returns (string[] memory) {
		return sports;
	}
	
	/**
	 * @dev Increments the last game id.
	 */
	function _incrementLastGameId() private returns (uint256) {
		_lastGameId+= 1;
		return _lastGameId;
	}

	/**
	 * @dev Increments the last bet id.
	 */
	function _incrementLastBetId() private returns (uint256) {
		_lastBetId += 1;
		return _lastBetId;
	}
	
	/**
	 * @dev Increments the last bets set id.
	 */
	function _incrementLastBetsSetId() private returns (uint256) {
		_lastBetsSetId += 1;
		return _lastBetsSetId;
	}

	/**
	 * @dev Increments the bets count for a given bettor.
	 * @param _address The bettor address
	 */
	function _incrementUserBetsCount(address _address) private {
		_userBetsCount[_address] = _userBetsCount[_address] + 1;
	}

	/**
	 * @dev Decrements the bets count for a given bettor.
	 * @param _address The bettor address
	 */
	function _decrementUserBetsCount(address _address) private {
		if (_userBetsCount[_address] > 0) {
			_userBetsCount[_address] = _userBetsCount[_address] - 1;
		}
	}

	/**
	 * @dev Get the bets count for a given bettor.
	 * @param _address The bettor address
	 */
	function getUserBetsCount(address _address) public view returns (uint256) {
		return _userBetsCount[_address];
	}

	/**
	 * @dev Create a token transfer contract for a given user.
	 * @param _address The user address
	 */
	function _createUserTokenTransferContract(address _address)
	private returns (bool) {
        TokenTransferV1 tokenTransferContract = new TokenTransferV1(
			address(tokenContract),
			address(liquidityContract),
			address(managers[0])
		);
        liquidityContract.setUserTokenTransferContract(
			_address,
			address(tokenTransferContract)
		);
		return true;
	}

	/**
	 * @dev Pay a won bet to the user
	 * @param _betsSetId The bets set id
	 */
    function payWonBet(uint256 _betsSetId) public returns (bool) {
		uint256 _totalOutcomeAmount = 0;
		bool _allWonBets = false;
		bool _gameSuspended;
		bool _anyGameSuspended = false;
		bool _isCombo = false;
		uint256 _outcomeComboAmount = 0;
		bool _welcomeBonusApplied = false;
		bool _isThereAnyBetsSetWithBonusApplied = false;
		TokenTransferV1 tokenTransferContract;

		if (betsMapping[_betsSetId].length > 1) {
			_isCombo = true;
			_outcomeComboAmount = betsSets[_betsSetId].amount;
		}
		_welcomeBonusApplied = betsSets[_betsSetId].welcomeBonusApplied;

		for (uint256 i=0; i<unpaidBetsSets[msg.sender].length; i++) {
			if (unpaidBetsSets[msg.sender][i] == _betsSetId) {
				(_allWonBets, _gameSuspended, _totalOutcomeAmount) = _checkWonBets(
					betsMapping[_betsSetId],
					_isCombo,
					_outcomeComboAmount
				);
				
				require(_allWonBets, "Core: There are lost bets in this bets set");

				if (betsSets[_betsSetId].bettorBonusAmount > 0) {
					_isThereAnyBetsSetWithBonusApplied = true;
				}

				if (_gameSuspended && !_anyGameSuspended) {
					_anyGameSuspended = true;
					_welcomeBonusApplied = false;
					_decrementUserBetsCount(msg.sender);
					betsSets[_betsSetId].welcomeBonusApplied = false;
					welcomeBonusContract.setBettorEnjoyedWelcomeBonus(msg.sender, false);
					welcomeBonusContract.setBettorEnjoyedWelcomeBonusOnSuspendedGame(msg.sender, true);
					
					if (betsSets[_betsSetId].bettorBonusAmount > 0) {
						bonusContract.setBettorBonus(msg.sender, betsSets[_betsSetId].bettorBonusAmount);
					}
				}

				for (uint256 j = i; j < unpaidBetsSets[msg.sender].length - 1; j++) {
					unpaidBetsSets[msg.sender][j] = unpaidBetsSets[msg.sender][j + 1];
				}

				unpaidBetsSets[msg.sender].pop();
				betsSets[_betsSetId].paid = true;
				break;
			}
		}

		if (_welcomeBonusApplied && !_anyGameSuspended) {
			_totalOutcomeAmount = _totalOutcomeAmount * welcomeBonusContract.getBonusMultiplier();
		}

		if (_anyGameSuspended) {
			_totalOutcomeAmount = betsSets[_betsSetId].amount;
		}

		if (!_allWonBets) {
			_totalOutcomeAmount = 0;
		}

		if (!_isThereAnyBetsSetWithBonusApplied || (_isThereAnyBetsSetWithBonusApplied && !_anyGameSuspended)) {
			require(_totalOutcomeAmount > 0, "Core: There are no bets to pay");
			require(liquidityContract.balance() >= _totalOutcomeAmount,
			"Core: Insufficient contract liquidity");
			require(_createUserTokenTransferContract(msg.sender),
			"Core: Error creating token transfer contract");
			tokenTransferContract = TokenTransferV1(
				liquidityContract.getUserTokenTransferContract(msg.sender)
			);
			require(tokenTransferContract.withdrawTokens(msg.sender, _totalOutcomeAmount),
			"Core: Withdraw couldn't be made");
		}

		emit PayWonBet(_betsSetId, msg.sender, _totalOutcomeAmount, _welcomeBonusApplied, _isThereAnyBetsSetWithBonusApplied);
		return true;
	}

	/**
	 * @dev Pay more than one won bet to the user at a time
	 * @param _betsSetIds The bets set ids array
	 */
	function payWonBets(uint256[] calldata _betsSetIds) external returns (bool) {
		for (uint256 i=0; i<_betsSetIds.length; i++) {
			require(betsSets[_betsSetIds[i]].bettorBonusAmount == 0,
			"Core: Bonus withdraw just can be made for one bet set at a time");
			
			payWonBet(_betsSetIds[i]);
		}
		return true;
	}

	/**
	 * @dev Check if given bets are won
	 * @param _betsIds The bets ids array
	 * @param _isCombo If the bets are a combo
	 * @param _outcomeComboAmount The combo outcome amount (if applicable)
	 */
	function _checkWonBets(
		uint256[] memory _betsIds,
		bool _isCombo,
		uint256 _outcomeComboAmount
	) private view returns (bool, bool, uint256) {
		uint256 _outcomeAmount = 0;
		uint256 _comboOdd = 1;
		uint256 _comboOddDecimals = 0;
		uint256 _gameId;
		uint256 _outcomeWinId;
		uint256 _marketId;
		bool _wonBet = true;
		bool _anyGameSuspended = false;
		Bet memory _bet;
		
		for (uint i=0; i<_betsIds.length; i++) {
			_bet = bets[_betsIds[i]];
			_gameId = _bet.gameId;
			_outcomeWinId = _bet.outcomeWinId;
			_marketId = _bet.marketId;
								
			require(games[_gameId].resolved, "Core: Some matches are not over yet");

			if (wasGameSuspended(_gameId)) {
				if (!_isCombo) {
					_outcomeAmount += _bet.amount;
				} else {
					_comboOdd *= 100;
					_comboOddDecimals += oddsDecimals;
				}

				_anyGameSuspended = true;
			} else {
				for (uint j=0; j<gameMarkets[_gameId].length; j++) {
					bool _matchedResolvedOutcome = false;
					for (uint k=0; k<gameMarkets[_gameId][j].resolvedOutcome.length; k++) {
						if (gameMarkets[_gameId][j].resolvedOutcome[k] == _outcomeWinId) {
							_matchedResolvedOutcome = true;
						}
					}
					if (gameMarkets[_gameId][j].marketId == _marketId
					&& _matchedResolvedOutcome
					&& _wonBet) {
						if (!_isCombo) {
							_outcomeAmount += _bet.amount*_bet.odd/(10**oddsDecimals);
						} else {
							_comboOdd *= _bet.odd;
							_comboOddDecimals += oddsDecimals;
						}
					}
					if (gameMarkets[_gameId][j].marketId == _marketId
					&& !_matchedResolvedOutcome
					&& _wonBet) {
						_wonBet = false;
					}
				}
			}
		}

		if (_isCombo) {
			_outcomeAmount = (_outcomeComboAmount*_comboOdd)/(10**_comboOddDecimals);
		}

		return (_wonBet, _anyGameSuspended, _outcomeAmount);
	}

	/**
	 * @dev Check if a game was suspended
	 * @param _gameId The game id
	 */
	function wasGameSuspended(uint256 _gameId) public view returns (bool) {
		string storage gameStatus = games[_gameId].status;
		return (keccak256(abi.encodePacked(gameStatus)) == keccak256(abi.encodePacked("SUS")) ||
				keccak256(abi.encodePacked(gameStatus)) == keccak256(abi.encodePacked("PST")) ||
				keccak256(abi.encodePacked(gameStatus)) == keccak256(abi.encodePacked("CAN")) ||
				keccak256(abi.encodePacked(gameStatus)) == keccak256(abi.encodePacked("ABD")));
	}

	/**
	 * @dev Set if live bets are allowed
	 * @param _allowLiveBets If live bets are allowed
	 */
	function setAllowLiveBets(bool _allowLiveBets) public onlyManager {
		allowLiveBets = _allowLiveBets;
	}
	
	/**
	 * @dev Get bets set ids of a given user
	 * @param _bettor The user address
	 */
	function getUserBetsSetIds(address _bettor)
	public view returns (uint256[] memory) {
		return usersBetsSets[_bettor];
	}

	/**
	 * @dev Get unpaid bets set ids of a given user
	 * @param _bettor The user address
	 */
	function getUnpaidUserBetsSets(address _bettor)
	public view returns (uint256[] memory) {
		return unpaidBetsSets[_bettor];
	}

	/**
	 * @dev Get bets that belong to a bet set
	 * @param _betsSetId The bets set id
	 */
	function getBetsMapping(uint256 _betsSetId)
	public view returns (uint256[] memory) {
		return betsMapping[_betsSetId];
	}

	/**
	 * @dev Get bets set by id
	 * @param _betsSetId The bets set id
	 */
	function getBetsSetById(uint256 _betsSetId)
	public view returns (BetsSet memory) {
		return betsSets[_betsSetId];
	}

	/**
	 * @dev Get bet by id
	 * @param _betId The bet id
	 */
	function getBetsById(uint256 _betId) public view returns (Bet memory) {
		return bets[_betId];
	}

	/**
	* @dev Allows to change managers
	*/
	function changeManager(address _manager, uint8 _index) public onlyManager {
		require(_index >= 0 && _index <= 2, "Core: Invalid index");
		managers[_index] = _manager;
	}

	/**
	 * @dev Set oracle address
	 * @param _oracle The oracle address
	 */
	function setOracleAddress(address _oracle) public onlyOwner {
		oracleAddress = _oracle;
	}

	/**
	 * @dev Set Liquidity smart contract address
	 * @param _liquidityAddress The liquidity address
	 */
	function setLiquidityContract(address _liquidityAddress) public onlyOwner {
		liquidityContract = ILiquidityV1(_liquidityAddress);
		liquidityAddress = _liquidityAddress;
	}
	
	/**
	 * @dev Set welcome bonus contract address
	 * @param _welcomeBonusAddress The welcome bonus address
	 */
	function setWelcomeBonusContract(address _welcomeBonusAddress) public onlyOwner {
		welcomeBonusContract = IWelcomeBonusV1(_welcomeBonusAddress);
		welcomeBonusAddress = _welcomeBonusAddress;
	}
	
	/**
	 * @dev Set bonus contract address
	 * @param _bonusAddress The bonus address
	 */
	function setBonusContract(address _bonusAddress) public onlyOwner {
		bonusContract = IBonusV1(_bonusAddress);
		bonusAddress = _bonusAddress;
	}
	
	/**
	 * @dev Set affiliate contract address
	 * @param _affiliateAddress The affiliate address
	 */
	function setAffiliateContract(address _affiliateAddress) public onlyOwner {
		affiliateContract = IAffiliateV1(_affiliateAddress);
		affiliateAddress = _affiliateAddress;
	}
}