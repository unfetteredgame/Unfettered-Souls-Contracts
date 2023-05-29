// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {GameItem, IERC1155GameItem} from "./interfaces/IERC1155GameItem.sol";
import "../interfaces/IManagers.sol";



contract ERC1155GameInventory is Ownable {
    using ERC165Checker for address;
    struct ClaimData {
        string playfabId;
        string playfabTxId;
        address player;
        uint256[] tokenIds;
        uint256[] amounts;
    }
    struct LeafData {
        string playfabId;
        string playfabTxId;
        uint256[] tokenIds;
        uint256[] amounts;
        bytes32[] merkleProof;
    }
    struct AllocationRecord {
        bytes32 merkleRootHash;
        uint256 startTime;
        uint256 endTime;
    }

    struct ClaimRecord {
        uint256[] tokenIds;
        uint256[] amounts;
        uint256 time;
    }
    struct TxDefinition {
        uint256[] tokenIds;
        uint256[] amounts;
    }
    AllocationRecord[] public withdrawDefinitions;
    uint256 public periodCount;
    uint256 public interval = 15 minutes;
    uint256 public distributionOffset = 5 minutes;

    IERC1155GameItem public itemsContract;
    IManagers public managers;

    // mapping(address => mapping(uint256 => uint256)) public playerItemsInInventory;
    mapping(address => mapping(string => TxDefinition)) private playerDeposits; //player=>playfabTxId=>TxDefinition
    mapping(string => bool) public completedTransactions;
    mapping(uint256 => mapping(address => ClaimRecord)) public claimRecords;
    mapping(address => mapping(string => uint256)) public test;
    mapping(address => mapping(string => TxDefinition)) private userClaimDefinitionForItem; //player=>playfabTxId=>TxDefinition

    mapping(uint256 => ClaimData[]) claimedPlayersForPeriods;

    address public authorizedAddress;
    address payable treasury;

    error StartTimeMustBeInTheFuture();
    error InvalidMerkleRootHash();
    error ClaimPeridNotStarted();
    error ThereIsActivePeriod();
    error ClaimPeriodEnded();
    error UsedPlayfabTxId();
    error NoActivePeriod();
    error AlreadyClaimed();
    error NotAuthorized();
    error NoAllocation();
    error AlreadySet();

    event CreateClaim(uint256 period, bytes32 merkleRootHash, uint256 startTime, uint256 endTime);
    event ClaimItems(address indexed player, string playfabId, uint256[] tokenIds, uint256[] amounts);
    event ChangeTreasuryAddress(address manager, address newAddress, bool approved);
	event AddItemsToGameInventory(address player, string playfabTxId, uint256[] tokenIds, uint256[] amounts);
	event SetClaimDefinition(address player, string playfabTxId, uint256[] tokenIds, uint256[] amounts);


    constructor(IManagers _managers, address _authorizedAddress, address payable _treasury) {
        managers = _managers;
        authorizedAddress = _authorizedAddress;
        treasury = _treasury;
    }

    modifier onlyManager() {
        if (!managers.isManager(msg.sender)) {
            revert NotAuthorized();
        }
        _;
    }

    modifier onlyAuthorizedAddress() {
        if (msg.sender != authorizedAddress) {
            revert NotAuthorized();
        }
        _;
    }

    function setItemsContract(IERC1155GameItem _itemsContract) external onlyOwner {
        if (address(itemsContract) != address(0)) {
            revert AlreadySet();
        }
        itemsContract = _itemsContract;
    }

    function setAuthorizedAddress(address _newAddress) external onlyManager {
        authorizedAddress = _newAddress;
        itemsContract.setAuthorizedAddress(_newAddress);
    }

    function setTreasury(address payable _newAddress) external onlyManager {
        string memory _title = "Set Treasury Address";
        bytes memory _encodedValues = abi.encode(_newAddress);
        managers.approveTopic(_title, _encodedValues);
        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            treasury = _newAddress;
            itemsContract.setTreasury(_newAddress);
            managers.deleteTopic(_title);
        }
        emit ChangeTreasuryAddress(msg.sender, _newAddress, _isApproved);
    }

    function isLastPeriodEnded() public view returns (bool) {
        if (periodCount == 0) return true;
        uint256 _currentPeriod = periodCount - 1;
        AllocationRecord memory _currentPeriodRecord = withdrawDefinitions[_currentPeriod];
        return block.timestamp > _currentPeriodRecord.endTime;
    }

    function createWithdrawDefinition(
        uint256 _startTime,
        bytes32 _merkleRootHash,
        address _nextAuthorizedAddress
    ) external onlyAuthorizedAddress {
        if (_merkleRootHash.length == 0) {
            revert InvalidMerkleRootHash();
        }
        if (_startTime <= block.timestamp) {
            revert StartTimeMustBeInTheFuture();
        }
        if (!isLastPeriodEnded()) {
            revert ThereIsActivePeriod();
        }

        uint256 _endTime = _startTime + interval - distributionOffset;

        withdrawDefinitions.push(
            AllocationRecord({merkleRootHash: _merkleRootHash, startTime: _startTime, endTime: _endTime})
        );
        authorizedAddress = _nextAuthorizedAddress;
        periodCount++;
        emit CreateClaim(periodCount, _merkleRootHash, _startTime, _endTime);
    }

    function claimItems(LeafData calldata _leafData) external {
        if (periodCount == 0) {
            revert NoActivePeriod();
        }
        uint256 _currentPeriod = periodCount - 1;
        AllocationRecord storage _currentPeriodRecord = withdrawDefinitions[_currentPeriod];

        if (block.timestamp < _currentPeriodRecord.startTime) {
            revert ClaimPeridNotStarted();
        }
        if (block.timestamp > _currentPeriodRecord.endTime) {
            revert ClaimPeriodEnded();
        }
        if (claimRecords[_currentPeriod][msg.sender].time != 0) {
            revert AlreadyClaimed();
        }

        if (completedTransactions[_leafData.playfabTxId]) {
            revert UsedPlayfabTxId();
        }

        bytes32 _leaf = keccak256(
            abi.encodePacked(
                msg.sender,
                _currentPeriod,
                _leafData.tokenIds,
                _leafData.amounts,
                _leafData.playfabId,
                _leafData.playfabTxId
            )
        );
        if (!MerkleProof.verifyCalldata(_leafData.merkleProof, _currentPeriodRecord.merkleRootHash, _leaf)) {
            revert NoAllocation();
        }

        completedTransactions[_leafData.playfabTxId] = true;

        claimRecords[_currentPeriod][msg.sender].amounts = _leafData.amounts;
        claimRecords[_currentPeriod][msg.sender].tokenIds = _leafData.tokenIds;
        claimRecords[_currentPeriod][msg.sender].time = block.timestamp;

        claimedPlayersForPeriods[_currentPeriod].push(
            ClaimData({
                playfabId: _leafData.playfabId,
                playfabTxId: _leafData.playfabTxId,
                player: msg.sender,
                tokenIds: _leafData.tokenIds,
                amounts: _leafData.amounts
            })
        );

        itemsContract.transferToPlayer(msg.sender, _leafData.tokenIds, _leafData.amounts);

        emit ClaimItems(msg.sender, _leafData.playfabId, _leafData.tokenIds, _leafData.amounts);
    }


    //Tested
    function addItemsToGameInventory(
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts,
        string memory _playfabTxId
    ) external {
        if (completedTransactions[_playfabTxId]) {
            revert UsedPlayfabTxId();
        }
        completedTransactions[_playfabTxId] = true;
        itemsContract.transferToGame(msg.sender, _tokenIds, _amounts);
        playerDeposits[msg.sender][_playfabTxId] = TxDefinition({tokenIds: _tokenIds, amounts: _amounts});
		emit AddItemsToGameInventory(msg.sender, _playfabTxId, _tokenIds, _amounts);
    }

    //Tested
    function getPlayerDepositData(
        address _player,
        string calldata _playfabTxId
    ) external view returns (TxDefinition memory) {
        return playerDeposits[_player][_playfabTxId];
    }


    //Tested
    function setClaimDefinition(
        address _player,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts,
        string calldata _playfabTxId
    ) external onlyAuthorizedAddress {
        if (completedTransactions[_playfabTxId]) {
            revert UsedPlayfabTxId();
        }
        userClaimDefinitionForItem[_player][_playfabTxId] = TxDefinition({tokenIds: _tokenIds, amounts: _amounts});
		emit SetClaimDefinition(_player, _playfabTxId, _tokenIds, _amounts);
    }

    //Tested
    function claim(string calldata _playfabTxId) external {
        if (userClaimDefinitionForItem[msg.sender][_playfabTxId].amounts.length == 0) {
            revert NoAllocation();
        }
        if (completedTransactions[_playfabTxId]) {
            revert AlreadyClaimed();
        }
        if (completedTransactions[_playfabTxId]) {
            revert UsedPlayfabTxId();
        }
        completedTransactions[_playfabTxId] = true;

        for (uint256 i = 0; i < userClaimDefinitionForItem[msg.sender][_playfabTxId].amounts.length; i++) {
            itemsContract.claimForPlayer(
                msg.sender,
                userClaimDefinitionForItem[msg.sender][_playfabTxId].tokenIds[i],
                userClaimDefinitionForItem[msg.sender][_playfabTxId].amounts[i]
            );
        }
        emit ClaimItems(
            msg.sender,
            _playfabTxId,
            userClaimDefinitionForItem[msg.sender][_playfabTxId].tokenIds,
            userClaimDefinitionForItem[msg.sender][_playfabTxId].amounts
        );
    }

    //Read Functions
    function getPlayerClaimDefinition(
        address _player,
        string calldata _playfabTxId
    ) public view returns (TxDefinition memory) {
        return userClaimDefinitionForItem[_player][_playfabTxId];
    }

    //Tested
    function withdraw() external payable onlyManager {
        itemsContract.withdraw();
    }
}
