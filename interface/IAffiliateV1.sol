// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface IAffiliateV1 {
    function addToWhiteList(address _address) external;
    function removeFromWhiteList(address _address) external;
    function addManyToWhitelist(address[] memory _addresses) external;
    function enableWhitelist() external;
    function disableWhitelist() external;
    function isWhitelistEnabled() external view returns (bool);
    function isWhitelisted(address _address) external view returns (bool);
    function referredExists(address _referred) external view returns (bool);
    function addRewardInfoToReferral(address _referral, address _referred, uint256 _betsSetId, uint256 _reward) external returns (bool);
    function getReferralBonusRate(address _referral) external view returns (uint256);
    function getReferralInfo(address _referral) external view returns (IAffiliateV1.Referral[] memory);
    function amountToPayReferral(address _referral, uint256 _totalAmountWithDecimals) external view returns (uint256);
    function addReferralBonusRates(uint256 _lowerBound, uint256 _rate) external;
    function getReferralBonusRates() external view returns (uint256[] memory, uint256[] memory);
    function eraseReferralBonusRates() external;
    function getCoreContractAddress() external view returns (address);
    function setCoreContractAddress(address _core) external;
    function changeManager(address _manager, uint8 _index) external;
    
    struct Referral {
        address referred;
        uint256 betsSetsId;
        uint256 reward;
        uint256 referredCounter;
        uint256 timestamp;
    }
}
