// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IBonusV1 {
    function setBettorBonus(address _address, uint256 _amount) external;
    function getBettorBonus(address _address) external view returns (uint256);
    function enableBonus() external;
    function disableBonus() external;
    function isBonusEnabled() external view returns (bool);
    function isUserApplicableForBonus(address _address) external view returns (bool);
    function betMeetsRequirements(uint256 _odd) external view;
    function setMinimumOddRequirement(uint256 _minimumOdd) external returns (bool);
    function getCoreContractAddress() external view returns (address);
    function setCoreContractAddress(address _core) external returns (bool);
    function changeManager(address _manager, uint8 _index) external;
}
