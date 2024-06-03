// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @author BetcoinPro
 * @title  Bonus smart contract
 * @notice Bonus contract to manage bonus for bettors.
 * 		   The contract sets bonus amount for bettors,
 * 		   as well as checking if bettor is applicable to enjoy bonus.
 */

contract BonusV1 is UUPSUpgradeable, OwnableUpgradeable {
	modifier onlyManager() {
		require(managers[0] == msg.sender || managers[1] == msg.sender
		|| managers[2] == msg.sender, "Bonus: Not manager");
		_;
	}

	modifier onlyCore() {
		require(_coreAddress == msg.sender, "Bonus: Not Core");
		_;
	}

	mapping(uint8 => address) public managers;
	mapping(address => uint256) private bettorsWhiteList;
	bool private _isBonusEnabled;

	ERC20 private _tokenContract;
	address private _coreAddress;

    function initialize(address coreAddress) public initializer {
		__Ownable_init();
		__UUPSUpgradeable_init();

		_coreAddress = coreAddress;
		managers[0] = msg.sender;
		managers[1] = _coreAddress;
		_isBonusEnabled = true;
	}

    function _authorizeUpgrade(address) internal override onlyOwner {}

	/**
	 * @dev Set an amount for the bettor to enjoy bonus
	 */
	function setBettorBonus(address _address, uint256 _amount)
	public onlyManager {
		bettorsWhiteList[_address] = _amount;
	}

	/**
	 * @dev Get the amount for the bettor to enjoy bonus
	 */
	function getBettorBonus(address _address)
	public view returns (uint256) {
		return bettorsWhiteList[_address];
	}

	/**
	 * @dev Enable bonus
	 */
	function enableBonus() public onlyManager {
		_isBonusEnabled = true;
	}
 
	/**
	 * @dev Disable bonus
	 */
	function disableBonus() public onlyManager {
		_isBonusEnabled = false;
	}

	/**
	 * @dev Return if bonus is enabled
	 */
	function isBonusEnabled() public view returns (bool) {
		return _isBonusEnabled;
	}

	/**
	 * @dev Check if user is applicable to enjoy bonus
	 */
	function isUserApplicableForBonus(address _address)
	public view returns (bool) {
		if(_isBonusEnabled
		&& bettorsWhiteList[_address] > 0){
			return true;
		}

		return false;
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
}