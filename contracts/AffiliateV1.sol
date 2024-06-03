// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @author BetcoinPro
 * @title  Affiliate smart contract
 * @notice Affiliate contract to manage referrals and rewards.
 * 		   Any user account should be whitelisted previously in order to be able to get rewards
 * 	   	   with the addToWhiteList() function. To make it work, the whitelist should be enabled.
 * 		   The referral bonus rates are set by the manager with the addReferralBonusRates() function.
 */

contract AffiliateV1 is UUPSUpgradeable, OwnableUpgradeable {
	modifier onlyManager() {
		require(managers[0] == msg.sender || managers[1] == msg.sender
		|| managers[2] == msg.sender, "Affiliate: Not manager");
		_;
	}
	
	modifier onlyCore() {
		require(coreAddress == msg.sender, "Affiliate: Not Core");
		_;
	}

    modifier onlyNotWhitelistedReferrals(address _address) {
		require(!_referralsWhiteList[_address],
		"Affiliate: This address is already whitelisted");
		_;
	}

	struct Referral {
		address referred;
		uint256 betsSetsId;
		uint256 reward;
		uint256 referredCounter;
		uint256 timestamp;
	}
	
	struct Referred {
		address referral;
		uint256 timestamp;
	}
	
    mapping(uint8 => address) public managers;
	uint256[] private _referralBonusRatesLowerBound;
	uint256[] private _referralBonusRatesAmount;
	mapping(address => Referral[]) public referrals;
	mapping(address => Referred) public referred;
	mapping(address => uint256) public referredCounter;
	bool private _isWhitelistEnabled;
	mapping(address => bool) private _referralsWhiteList;

	address public coreAddress;
	
	function initialize(address _coreAddress) public initializer {
		__Ownable_init();
		__UUPSUpgradeable_init();

        coreAddress = _coreAddress;
		managers[0] = msg.sender;

		_isWhitelistEnabled = false;

		addReferralBonusRates(0, 15);
		addReferralBonusRates(50, 20);
		addReferralBonusRates(100, 25);
		addReferralBonusRates(500, 35);
	}

    function _authorizeUpgrade(address) internal override onlyOwner {}
	
	/**
	 * @dev Add an address to the whitelist
	 */
	function addToWhiteList(address _address)
	public onlyManager onlyNotWhitelistedReferrals(_address) {
		_referralsWhiteList[_address] = true;
	}
 
	/**
	 * @dev Remove an address from the whitelist
	 */
	function removeFromWhiteList(address _address) public onlyManager {
		_referralsWhiteList[_address] = false;
	}
 
	/**
	 * @dev Add more than one address to the whitelist
	 */
	function addManyToWhitelist(address[] memory _addresses) public onlyManager {
		for (uint256 i = 0; i < _addresses.length; i++) {
			addToWhiteList(_addresses[i]);
		}
	}
 
	/**
	 * @dev Enable the whitelist
	 */
	function enableWhitelist() public onlyManager {
		_isWhitelistEnabled = true;
	}
 
	/**
	 * @dev Disable the whitelist
	 */
	function disableWhitelist() public onlyManager {
		_isWhitelistEnabled = false;
	}

	/**
	 * @dev Return if whitelist is enabled
	 */
	function isWhitelistEnabled() public view returns (bool) {
		return _isWhitelistEnabled;
	}
	
	/**
	 * @dev Return if an address is whitelisted
	 */
	function isWhitelisted(address _address) public view returns (bool) {
		return _referralsWhiteList[_address];
	}
	
	/**
	 * @dev Add referred to mapping
	 */
	function addReferred(address _referral, address _referred) private {
		if (referred[_referred].referral == address(0)
		&& referred[_referred].timestamp == 0) {
			referred[_referred] = Referred(_referral, block.timestamp);
		}
	}
	
	/**
	 * @dev Check if referred already exists
	 */
	function referredExists(address _referred) public view returns (bool) {
		if (referred[_referred].referral != address(0)
		&& referred[_referred].timestamp != 0) {
			return true;
		}
		return false;
	}
	
	/**
	 * @dev Add reward details to referrals mapping
	 * @param _referral The referral address
	 * @param _referred The referred address
	 * @param _betsSetId The id of the bets set
	 * @param _reward The amount the referral will be paid
	 */
	function addRewardInfoToReferral(
		address _referral,
		address _referred,
		uint256 _betsSetId,
		uint256 _reward
	) public onlyCore returns (bool) {
		addReferred(_referral, _referred);
		require(referredExists(_referred), "Affiliate: referred doesn't exist");
		referrals[_referral].push(Referral(
			_referred,
			_betsSetId,
			_reward,
			_incrementReferralCounter(_referral),
			block.timestamp
		));
		return true;
	}
	
	/**
	 * @dev Get referral bonus percentage to pay according to referralBonusRatesAmount array
	 */
	function getReferralBonusRate(address _referral) public view returns (uint256) {
		uint256 rate = _referralBonusRatesAmount[0];
		for (uint i = 1; i < _referralBonusRatesLowerBound.length; i++) {
			if (referredCounter[_referral] < _referralBonusRatesLowerBound[i]) {
				break;
			}
			rate = _referralBonusRatesAmount[i];
		}
		return rate;
	}

	function getReferralInfo(address _referral)public view returns (Referral[] memory) {
		return referrals[_referral];
	}
	
	/**
	 * @dev Get amount that will be paid to referral
	 * @param _referral The referral address
	 * @param _totalAmountWithDecimals The total bets set amount paid by the referred
	 */
	function amountToPayReferral(address _referral, uint256 _totalAmountWithDecimals)
	public view onlyCore returns (uint256) {
		uint256 _percentageRate = getReferralBonusRate(_referral);
		uint256 _bonusAmount = _totalAmountWithDecimals * _percentageRate / 100;
		return _bonusAmount;
	}
	
	/**
	 * @dev Increment referral counter
	 * @param _referral The referral address
	 */
	function _incrementReferralCounter(address _referral) private returns (uint256) {
		referredCounter[_referral] += 1;
		return referredCounter[_referral];
	}
	
	/**
	 * @dev Add bonus rates that will be paid to referrals
	 * @param _lowerBound The minimal referral amount
	 * @param _rate The bonus rate to be paid to a referral
	 */
	function addReferralBonusRates(uint256 _lowerBound, uint256 _rate)
	public onlyManager {
		_referralBonusRatesLowerBound.push(_lowerBound);
		_referralBonusRatesAmount.push(_rate);
	}
	
	/**
	 * @dev Get bonus rates that will be paid to referrals
	 * @return an array with lower bounds and rates
	 */
	function getReferralBonusRates()
	public view onlyManager returns (uint256[] memory, uint256[] memory) {
		return (_referralBonusRatesLowerBound, _referralBonusRatesAmount);
	}
	
	/**
	 * @dev Reset bonus rates
	 */
	function eraseReferralBonusRates() public onlyManager {
		delete _referralBonusRatesLowerBound;
		delete _referralBonusRatesAmount;
	}
	
	/**
	 * @dev Get core contract address
	 */
	function getCoreContractAddress() public view returns (address) {
		return coreAddress;
	}
	
	/**
	 * @dev Set core contract address
	 */
	function setCoreContractAddress(address _core) public onlyManager {
		coreAddress = _core;
	}
	
	/**
	 * @dev Allows to change managers
	 */
	function changeManager(address _manager, uint8 _index) public onlyManager {
		require(_index >= 0 && _index <= 2, "Invalid index");
		managers[_index] = _manager;
	}
}