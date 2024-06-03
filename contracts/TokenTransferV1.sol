// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//import "./ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./LiquidityV1.sol";

contract TokenTransferV1 {
    modifier onlyManager() {
        require(managers[0] == msg.sender || managers[1] == msg.sender
		|| managers[2] == msg.sender, "Core: Not manager");
        _;
    }

    modifier onlyCoreContract() {
		require(msg.sender == coreAddress, "TokenTransfer: Not core contract");
		_;
	}

    ERC20 public tokenContract;
    LiquidityV1 public liquidityContract;
    address coreAddress;

    mapping(uint8 => address) public managers;

    constructor(address _tokenAddress, address _liquidityAddress, address _managerAddress) {
        tokenContract = ERC20(_tokenAddress);
        liquidityContract = LiquidityV1(_liquidityAddress);
        coreAddress = msg.sender;
        managers[0] = _managerAddress;
    }

    /**
	* @dev Allow to change managers.
	*/
	function changeManager(address _manager, uint8 _index) public onlyManager {
		require(_index >= 0 && _index <= 2, "TokenTransfer: Invalid index");
		managers[_index] = _manager;
	}

    /**
	* @dev Allow to change Core address.
	*/
    function setCoreContractAddress(address _core)
	public onlyManager returns (bool) {
		coreAddress = _core;
		return true;
	}

    /**
	* @dev Withdraw `_amount` from contract to bettor.
	*/
    function withdrawTokens(address _to, uint256 _amount) external onlyCoreContract returns (bool) {
        require(tokenContract.balanceOf(address(liquidityContract)) >= _amount, "TokenTransfer: Insufficient balance");
        require(tokenContract.approve(address(liquidityContract), _amount), "TokenTransfer: Token approval failed");
        require(liquidityContract.withdraw(_to, _amount), "TokenTransfer: Token transfer failed");
        return true;
    }
}
