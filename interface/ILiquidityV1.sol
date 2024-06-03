// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ILiquidityV1 {
    function addLiquidity(uint256 _amount) external returns (bool);
    function withdrawLiquidity(uint256 _amount) external returns (bool);
    function _approveWithdrawal(uint256 _amount) external returns (bool);
    function withdraw(address _to, uint256 _amount) external returns (bool);
    function payForBet(address _from, uint256 _amount, bool _isUserApplicableForBonus) external returns (bool);
    function redeemWonBets() external returns (bool);
    function handleTax(address from, address to, uint256 amount) external returns (uint256);
    function exclude(address _account) external;
    function removeExclude(address _account) external;
    function isExcluded(address _account) external view returns (bool);
    function pause() external;
    function unpause() external;
    function balance() external view returns (uint256);
    function setCoreContractAddress(address _core) external returns (bool);
    function getUserTokenTransferContract(address _user) external returns (address);
	function setUserTokenTransferContract(address _user, address _contractAddress) external returns (bool);
    function setPayoutTax(uint256 _liquidity, uint256 _administration) external;
    function setTaxWallets(address _liquidity, address _administration) external;
    function enableTax() external;
    function disableTax() external;
    function changeManager(address _manager, uint8 _index) external;
}