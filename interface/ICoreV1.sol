// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

struct Game {
    string ipfsHash;
    uint64 sportId;
    uint256 startsAt;
    string status;
    bool resolved;
    bool enabled;
}

struct Market {
    uint256 marketId;
    uint64 [] odds;
    uint64 [] outcomesIds;
    uint64 [] resolvedOutcome;
    bool enabled;
}

struct Bet {
    uint256 sportId;
    uint256 gameId;
    uint256 marketId;
    uint256 amount;
    uint64 odd;
    uint64 outcomeWinId;
}

struct BetsSet {
    uint256 amount;
    bool paid;
    uint256 createdAt;
    bool welcomeBonusApplied;
}

interface ICoreV1 {
    event AddGame(uint256 indexed gameId);
    event EditGame(uint256 indexed gameId);
    event AddMarketsToGame(uint256 indexed gameId);
    event EditGameMarkets(uint256 indexed gameId);
    event PutBets(
        uint256 indexed betsSetsId,
        address indexed sender,
        uint256 paidAmount,
        address indexed referral,
        uint256 referralReward,
        bool welcomeBonusApplied
    );
    event PayWonBet(
        uint256 indexed betsSetId,
        address sender,
        uint256 totalOutcomeAmount,
        bool welcomeBonusApplied
    );

    function getGamesByDate(uint256 _date) external returns (uint256[] memory);
    function addGame(
        Game memory _gameArray,
        Market[] memory _gameMarketsArray,
        uint256 _date
    ) external returns (uint256);
    function editGame(Game calldata _game, uint256 _date) external;
    function getGameById(uint256 _id) external returns (Game memory);
    function addMarketsToGame(uint256 _gameOracleId, Market[] memory _gameMarketsArray) external;
    function editGameMarkets(uint256 _gameOracleId, Market[] memory _markets) external;
    function getGameMarkets(uint256 _gameId) external returns (Market[] memory);
    function enableGame(uint256 _gameOracleId) external;
    function disableGame(uint256 _gameOracleId) external;
    function putBets(
        Bet[] calldata _newBets,
        bool _isCombo,
        uint256 _paidAmount,
        address _referral,
        address _referred
    ) external returns (bool);
    function addSport(string memory _name) external returns (bool);
    function getSport(uint256 _id) external returns (string memory);
    function getSports() external returns (string[] memory);
    function payWonBet(uint256 _betsSetId) external returns (bool);
    function payWonBets(uint256[] calldata _betsSetIds) external returns (bool);
    function wasGameSuspended(uint256 _gameId) external returns (bool);
    function changeAllowLiveBets(bool _allowLiveBets) external;
    function getUserBetsSetIds(address _bettor) external returns (uint256[] memory);
    function getUnpaidUserBetsSets(address _bettor) external returns (uint256[] memory);
    function getBetsMapping(uint256 _betsSetId) external returns (uint256[] memory);
    function getBetsSetById(uint256 _betsSetId) external returns (BetsSet memory);
    function getBetsById(uint256 _betId) external returns (Bet memory);
    function changeManager(address _manager, uint8 _index) external;
    function setOracleAddress(address _oracle) external;
    function setLiquidityContract(address _liquidityAddress) external;
    function setWelcomeBonusContract(address _welcomeBonusAddress) external;
    function setAffiliateContract(address _affiliateAddress) external;
}
