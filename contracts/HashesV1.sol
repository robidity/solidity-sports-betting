// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract HashesV1 is UUPSUpgradeable, OwnableUpgradeable {
	modifier onlyManager() {
		require(managers[0] == msg.sender || managers[1] == msg.sender
		|| managers[2] == msg.sender, "Hashes: Not manager");
		_;
	}
	
	mapping(uint256 => string[]) private sportIpfsHashes;
    mapping(uint8 => address) public managers;
	string[] private globalIpfsHashes;
	
	string[] sportHashes;
	string[] globalHashes;

	function initialize() public initializer {
		__Ownable_init();
		__UUPSUpgradeable_init();

		managers[0] = msg.sender;
	}

    function _authorizeUpgrade(address) internal override onlyOwner {}
	
	/**
	 * @dev Get sport ipfs hashes
	 * @param _sportId The sport id
	 */
	function getSportIpfsHashes(uint256 _sportId)
	public view returns (string[] memory) {
		return sportIpfsHashes[_sportId];
	}

	/**
	 * @dev Set sport ipfs hashes
	 * @param _sportId The sport id
	 * @param _sportIpfsHashes[competitions, teams, markets] The array ipfs hashes for a given sport
	 * 	   competitions The competitions ipfs hash
	 * 	   teams The teams ipfs hash
	 *     markets The markets ipfs hash
	 */
	function setSportIpfsHashes(uint256 _sportId, string[] memory _sportIpfsHashes)
	public onlyManager {
		sportIpfsHashes[_sportId] = _sportIpfsHashes;
	}
	
	/**
	 * @dev Get global ipfs hashes
	 */
	function getGlobalIpfsHashes() public view returns (string[] memory) {
		return globalIpfsHashes;
	}
	
	/**
	 * @dev Set global ipfs hashes
	 * @param _globalIpfsHashes[countries]
	 *     countries The countries ipfs hash
	 */
	function setGlobalIpfsHashes(string[] memory _globalIpfsHashes)
	public onlyManager {
		globalIpfsHashes = _globalIpfsHashes;
	}
	
	/**
	 * @dev Allows to change managers
	 */
	function changeManager(address _manager, uint8 _index) public onlyManager {
		require(_index >= 0 && _index <= 2, "Invalid index");
		managers[_index] = _manager;
	}
}