// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interface/ILiquidityV1.sol";

/**
 * @author BetcoinPro
 * @title  Liquidity smart contract
 * @notice Liquidity contract to manage ERC20 tokens liquidity.
 * 		   The contract is used to add, approve, withdraw and transfer ERC20 tokens.
 */

contract LiquidityV1 is UUPSUpgradeable, OwnableUpgradeable {
	modifier onlyManager() {
        require(managers[0] == msg.sender || managers[1] == msg.sender
		|| managers[2] == msg.sender, "Liquidity: Not manager");
        _;
    }
	modifier onlyCoreContract() {
		require(msg.sender == coreAddress, "Liquidity: Not core contract");
		_;
	}
	
	ERC20 public tokenContract;
	uint256 public tokenDecimals;
	
	address public coreAddress;
    
    mapping(uint8 => address) public managers;
    mapping(string => address) private taxWallets;
    mapping(address => bool) private excludeList;
    mapping(string => uint256) private payoutTaxes;
	mapping(address => address) private userTokenTransferContract;

	function initialize(address _tokenAddress) public initializer {
		__Ownable_init();
		__UUPSUpgradeable_init();

		tokenContract = ERC20(_tokenAddress);
		tokenDecimals = tokenContract.decimals();		
		managers[0] = msg.sender;
	}

	function _authorizeUpgrade(address) internal override onlyOwner {}
	
	/**
	 * @dev Add ERC20 tokens liquidity to this contract.
	 */
	function addLiquidity(uint256 _amount) external onlyManager returns (bool) {
		tokenContract.transferFrom(msg.sender, address(this), _amount);
		return true;
	}

	/**
	 * @dev Approve to withdraw ERC20 tokens liquidity from this contract.
	 */
	function approveWithdrawLiquidity(uint256 _amount)
	external onlyManager returns (bool) {
		require(_amount <= tokenContract.balanceOf(address(this)),
		"Liquidity: Not enough balance");
		tokenContract.approve(msg.sender, _amount);
		return true;
	}

	/**
	 * @dev Withdraw ERC20 tokens liquidity from this contract.
	 */
	function withdrawLiquidity(uint256 _amount)
	external onlyManager returns (bool) {
		require(tokenContract.allowance(address(this), msg.sender) >= _amount,
		"Liquidity: Not enough allowance");
		require(_amount <= tokenContract.balanceOf(address(this)),
		"Liquidity: Not enough balance");
		tokenContract.transfer(msg.sender, _amount);
		return true;
	}

	/**
	 * @dev Withdraw `_amount` from contract to bettor.
	 */
	function withdraw(address _to, uint256 _amount) external returns (bool) {
		require(userTokenTransferContract[_to] == msg.sender,
		"Liquidity: Caller is not the associated TokenTransferContract");
		return tokenContract.transfer(_to, _amount);
	}
	
	/**
	 * @dev Pay to this contract in order to make a bet.
	 */
	function payForBet(address _from, uint256 _amount, bool _isUserApplicableForBonus)
	external onlyCoreContract returns (bool) {
		require(balance() >= _amount,
		"Liquidity: Insufficient contract balance. Amount should be lower");
		if (!_isUserApplicableForBonus) {
			require(tokenContract.transferFrom(_from, address(this), _amount),
			"Liquidity: Tokens were not transferred");
		}
		return true;
	}
	
	/**
	 * @dev Get balance of this contract.
	 */
	function balance() public view returns (uint256) {
		return tokenContract.balanceOf(address(this));
	}

	/**
	 * @dev Set core contract address.
	 */
	function setCoreContractAddress(address _core)
	public onlyManager returns (bool) {
		coreAddress = _core;
		return true;
	}

	/**
	 * @dev Get TokenTransfer contract address for a given user.
	 */
	function getUserTokenTransferContract(address _user)
	external view returns (address) {
		return userTokenTransferContract[_user];
	}

	/**
	 * @dev Set TokenTransfer contract address for a given user.
	 */
	function setUserTokenTransferContract(address _user, address _contractAddress)
	external onlyCoreContract returns (bool) {
		if(userTokenTransferContract[_user] == address(0)){
			userTokenTransferContract[_user] = _contractAddress;
		}
		return true;
	}
	
	/**
	 * @dev Allow to change managers.
	 */
	function changeManager(address _manager, uint8 _index) public onlyManager {
		require(_index >= 0 && _index <= 2, "Liquidity: Invalid index");
		managers[_index] = _manager;
	}
	
}