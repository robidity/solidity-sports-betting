// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IWelcomeBonusV1 {
    function addToWhiteList(address _address) external;
    function removeFromWhiteList(address _address) external;
    function addManyToWhitelist(address[] memory _addresses) external;
    function enableWhitelist() external;
    function disableWhitelist() external;
    function isWhitelistEnabled() external view returns (bool);
    function isWhitelisted(address _address) external view returns (bool);
    function enableWelcomeBonus() external;
    function disableWelcomeBonus() external;
    function isWelcomeBonusEnabled() external view returns (bool);
    function didBettorEnjoyWelcomeBonus(address _address) external view returns (bool);
    function setBettorEnjoyedWelcomeBonus(address _address, bool _value) external;
    function didBettorEnjoyWelcomeBonusOnSuspendedGame(address _address) external view returns (bool);
    function setBettorEnjoyedWelcomeBonusOnSuspendedGame(address _address, bool _value) external;
    function isUserApplicableForBonus(address _address) external view returns (bool);
    function betMeetsRequirements(uint256 _amount, uint256 _odd) external view;
    function setBetAmountRequirements(uint256 _minimumBetAmount, uint256 _maximumBetAmount) external returns (bool);
    function setMinimumOddRequirement(uint256 _minimumOdd) external returns (bool);
    function getCoreContractAddress() external view returns (address);
    function setCoreContractAddress(address _core) external returns (bool);
    function changeManager(address _manager, uint8 _index) external;
    function getBonusMultiplier() external view returns (uint256);
    function setBonusMultiplier(uint256 _multiplier) external;
}
