// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @author BetcoinPro
 * @title  Welcome bonus smart contract
 * @notice Welcome bonus contract to manage welcome bonus for bettors.
 * 		   The contract sets requirements and bonus multiplier for bettors,
 * 		   as well as checking if bettor is applicable to enjoy bonus
 * 		   and if bet meets the requirements.
 */

contract WelcomeBonusV1 is UUPSUpgradeable, OwnableUpgradeable {
	modifier onlyManager() {
		require(managers[0] == msg.sender || managers[1] == msg.sender
		|| managers[2] == msg.sender, "WB: Not manager");
		_;
	}

	modifier onlyCore() {
		require(_coreAddress == msg.sender, "WB: Not Core");
		_;
	}

	mapping(uint8 => address) public managers;
	mapping(address => bool) private bettorsEnjoyedWelcomeBonus;
	mapping(address => bool) private bettorsEnjoyedWelcomeBonusOnSuspendedGame;
	uint256 public minimumOdd;
	uint256 public minimumBetAmount;
	uint256 public maximumBetAmount;
	bool private _isWelcomeBonusEnabled;
	uint256 public bonusMultiplier;

	ERC20 private _tokenContract;
	address private _coreAddress;

    uint8 private _tokenDecimals;

    function initialize(address tokenAddress, address coreAddress) public initializer {
		__Ownable_init();
		__UUPSUpgradeable_init();

		_coreAddress = coreAddress;
		managers[0] = msg.sender;
		managers[1] = _coreAddress;

		_tokenContract = ERC20(tokenAddress);
		_tokenDecimals = _tokenContract.decimals();

		minimumOdd = 15*(10 ** (_tokenDecimals-1)); //1.5
		minimumBetAmount = 20*(10 ** (_tokenDecimals)); //20
		maximumBetAmount = 50*(10 ** (_tokenDecimals)); //50
		_isWelcomeBonusEnabled = false;
		setBonusMultiplier(2);
	}

    function _authorizeUpgrade(address) internal override onlyOwner {}

	/**
	 * @dev Enable welcome bonus
	 */
	function enableWelcomeBonus() public onlyManager {
		_isWelcomeBonusEnabled = true;
	}
 
	/**
	 * @dev Disable welcome bonus
	 */
	function disableWelcomeBonus() public onlyManager {
		_isWelcomeBonusEnabled = false;
	}

	/**
	 * @dev Return if welcome bonus is enabled
	 */
	function isWelcomeBonusEnabled() public view returns (bool) {
		return _isWelcomeBonusEnabled;
	}
    
	/**
	 * @dev Return if bettor have already enjoyed welcome bonus
	 */
	function didBettorEnjoyWelcomeBonus(address _address)
	public view returns (bool) {
		return bettorsEnjoyedWelcomeBonus[_address];
	}

	/**
	 * @dev Set if bettor have enjoyed welcome bonus to true or false
	 */
	function setBettorEnjoyedWelcomeBonus(address _address, bool _value)
	public onlyCore {
		bettorsEnjoyedWelcomeBonus[_address] = _value;
	}
	
	/**
	 * @dev Return if bettor have been returned welcome bonus due to
	 * suspended game 
	 */
	function didBettorEnjoyWelcomeBonusOnSuspendedGame(address _address)
	public view returns (bool) {
		return bettorsEnjoyedWelcomeBonusOnSuspendedGame[_address];
	}

	/**
	 * @dev Set if bettor have been returned welcome bonus due to
	 * suspended game to true or false
	 */
	function setBettorEnjoyedWelcomeBonusOnSuspendedGame(address _address, bool _value)
	public onlyCore {
		bettorsEnjoyedWelcomeBonusOnSuspendedGame[_address] = _value;
	}

	/**
	 * @dev Check if user is applicable to enjoy bonus
	 */
	function isUserApplicableForBonus(address _address)
	public view returns (bool) {
		if(_isWelcomeBonusEnabled
		&& (!didBettorEnjoyWelcomeBonus(_address)
			|| didBettorEnjoyWelcomeBonusOnSuspendedGame(_address))){
			return true;
		}
		
		return false;
	}

	/**
	 * @dev Check if bet meets the requirements
	 * @param _amount The total bet amount
	 * @param _odd The bet odd
	 */
	function betMeetsRequirements(uint256 _amount, uint256 _odd) public view {
		if(minimumOdd > 0){ //If higher than 0 means it is enabled
			require(_odd >= minimumOdd,
			"WB: The odd you are betting for should be higher");
		}
		if(minimumBetAmount > 0){ //If higher than 0 means it is enabled
			require(_amount >= minimumBetAmount,
			"WB: Your bet should be higher");
		}
		if(maximumBetAmount > 0){ //If higher than 0 means it is enabled
			require(_amount <= maximumBetAmount,
			"WB: Your bet should be lower");
		}
	}

	/**
	 * @dev Set minimum and maximum bet amount requirements.
	 * @param _minimumBetAmount The minimum amount to bet on. Set it to 0 to disabled it
	 * @param _maximumBetAmount The maximum amount to bet on. Set it to 0 to disabled it
	 */
	function setBetAmountRequirements(
		uint256 _minimumBetAmount,
		uint256 _maximumBetAmount
	) public onlyManager returns (bool) {
		minimumBetAmount = _minimumBetAmount;
		maximumBetAmount = _maximumBetAmount;
		return true;
	}

	/**
	 * @dev Set minimum odd requirement.
	 * @param _minimumOdd The minimum odd to bet on. Set it to 0 to disabled it
	 */
	function setMinimumOddRequirement(uint256 _minimumOdd)
	public onlyManager returns (bool) {
		minimumOdd = _minimumOdd;
		return true;
	}

	/**
	 * @dev Get core contract address
	 */
	function getCoreContractAddress() public view returns (address) {
		return _coreAddress;
	}

	/**
	 * @dev Set core contract address
	 */
	function setCoreContractAddress(address _core)
	public onlyManager returns (bool) {
		_coreAddress = _core;
		return true;
	}

	/**
	 * @dev Allow to change managers
	 */
	function changeManager(address _manager, uint8 _index) public onlyManager {
		require(_index >= 0 && _index <= 2, "Invalid index");
		managers[_index] = _manager;
	}

	/**
	 * @dev Get multiplier for paid amount when bettor takes advantage of bonus
	 */
	function getBonusMultiplier() public view returns (uint256) {
		return bonusMultiplier;
	}

	/**
	 * @dev Set multiplier for paid amount when bettor takes advantage of bonus
	 */
	function setBonusMultiplier(uint256 _multiplier) public onlyManager {
		bonusMultiplier = _multiplier;
	}
}