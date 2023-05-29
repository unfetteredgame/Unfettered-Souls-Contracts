// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IManagers.sol";
import "../interfaces/IPlayToEarnVault.sol";
import {ClaimData, IWithdrawClaim} from "../interfaces/IWithdrawClaim.sol";

contract WithdrawClaim is IWithdrawClaim, ERC165Storage {
    using SafeERC20 for IERC20;

    //Structs
    struct AllocationRecord {
        bytes32 merkleRootHash;
        uint256 totalAmount;
        uint256 startTime;
        uint256 endTime;
        uint256 remainingAmount;
    }
    struct ClaimRecord {
        uint256 time;
        uint256 amount;
    }

    //State Variables
    IManagers private managers;
    AllocationRecord[] public withdrawDefinitions;
    IPlayToEarnVault public vaultContract;

    uint256 public periodCount;

    address public soulsTokenAddress;
    address public authorizedAddress;

    mapping(uint256 => mapping(address => ClaimRecord)) public claimRecords;
    mapping(uint256 => ClaimData[]) claimedPlayersForPeriods;

    //Custom Errors
    error AddressCannotBeManagerAddress();
    error StartTimeMustBeInTheFuture();
    error NotEnoughBalanceInContract();
    error InvalidMerkleRootHash();
    error ClaimPeridNotStarted();
    error AddressCannotBeZero();
    error ThereIsActivePeriod();
    error NotAuthorizedCaller();
    error ClaimPeriodEnded();
    error ZeroTotalAmount();
    error NoActivePeriod();
    error AlreadyClaimed();
    error OnlyManagers();
    error NoAllocation();

    //Events
    event CreateClaim(uint256 period, bytes32 merkleRootHash, uint256 totalAmount, uint256 startTime, uint256 endTime);
    event Claim(address indexed player, string playfabId, uint256 amount);
    event SetAuthorizedAddress(address manager, address newAddress, bool isApproved);
    event WithdrawTokens(address manager, uint256 amount, address receiver, bool isApproved);

    constructor(address _managersContract, address _soulsTokenAddress, address _authorizedAddress) {
        soulsTokenAddress = _soulsTokenAddress;
        authorizedAddress = _authorizedAddress;
        managers = IManagers(_managersContract);
        vaultContract = IPlayToEarnVault(msg.sender);
        _registerInterface(type(IWithdrawClaim).interfaceId);
    }

    //Modifiers
    modifier onlyManager() {
        if (!managers.isManager(msg.sender)) {
            revert OnlyManagers();
        }
        _;
    }

    //Write Functions
    //Managers function
    function setAuthorizedAddress(address _newAddress) external onlyManager {
        if (_newAddress == address(0)) {
            revert AddressCannotBeZero();
        }
        if (managers.isManager(_newAddress)) {
            revert AddressCannotBeManagerAddress();
        }

        string memory _title = "Set withdraw claim service address";

        bytes memory _encodedValues = abi.encode(_newAddress);
        managers.approveTopic(_title, _encodedValues);

        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            authorizedAddress = _newAddress;
            managers.deleteTopic(_title);
        }
        emit SetAuthorizedAddress(msg.sender, _newAddress, _isApproved);
    }

    //Managers function
    function withdrawTokens(address _receiver) external onlyManager {
        if (_receiver == address(0)) {
            revert AddressCannotBeZero();
        }
        string memory _title = "Withdraw balance from withdraw claim contract";
        bytes memory _encodedValues = abi.encode(_receiver);
        managers.approveTopic(_title, _encodedValues);

        IERC20 _soulsToken = IERC20(soulsTokenAddress);
        uint256 _balance = _soulsToken.balanceOf(address(this));
        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            _soulsToken.safeTransfer(msg.sender, _balance);
            managers.deleteTopic(_title);
        }
        emit WithdrawTokens(msg.sender, _balance, _receiver, _isApproved);
    }

    function createWithdrawDefinition(
        uint256 _startTime,
        bytes32 _merkleRootHash,
        uint256 _totalAmount,
        address _nextAuthorizedAddress
    ) external {
        if (msg.sender != authorizedAddress) {
            revert NotAuthorizedCaller();
        }
        if (_merkleRootHash.length == 0) {
            revert InvalidMerkleRootHash();
        }
        if (_startTime <= block.timestamp) {
            revert StartTimeMustBeInTheFuture();
        }
        if (!isLastPeriodEnded()) {
            revert ThereIsActivePeriod();
        }

        if (_totalAmount == 0) {
            revert ZeroTotalAmount();
        }

        if (IERC20(soulsTokenAddress).balanceOf(address(this)) < _totalAmount) {
            revert NotEnoughBalanceInContract();
        }

        uint256 _interval = vaultContract.intervalBetweenDistributions();
        uint256 _endTime = _startTime + _interval - vaultContract.distributionOffset();

        withdrawDefinitions.push(
            AllocationRecord({
                merkleRootHash: _merkleRootHash,
                totalAmount: _totalAmount,
                startTime: _startTime,
                endTime: _endTime,
                remainingAmount: _totalAmount
            })
        );
        authorizedAddress = _nextAuthorizedAddress;
        periodCount++;
        emit CreateClaim(periodCount, _merkleRootHash, _totalAmount, _startTime, _endTime);
    }

    function claimTokens(
        string calldata _playfabId,
        string calldata _playfabTxId,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external {
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

        if (claimRecords[_currentPeriod][msg.sender].amount != 0) {
            revert AlreadyClaimed();
        }
        bytes32 _leaf = keccak256(abi.encodePacked(msg.sender, _currentPeriod, _amount, _playfabId, _playfabTxId));
        if (!MerkleProof.verifyCalldata(_merkleProof, _currentPeriodRecord.merkleRootHash, _leaf)) {
            revert NoAllocation();
        }

        claimRecords[_currentPeriod][msg.sender].amount = _amount;
        claimRecords[_currentPeriod][msg.sender].time = block.timestamp;
        claimedPlayersForPeriods[_currentPeriod].push(
            ClaimData({
                playfabId: _playfabId,
                playfabTxId: _playfabTxId,
                player: msg.sender,
                amount: _amount,
                claimTime: block.timestamp
            })
        );
        _currentPeriodRecord.remainingAmount -= _amount;
        IERC20 _soulsToken = IERC20(soulsTokenAddress);
        _soulsToken.safeTransfer(msg.sender, _amount);
        emit Claim(msg.sender, _playfabId, _amount);
    }

    //Read Functions
    function getClaimRecords(uint256 _period) public view returns (ClaimData[] memory _claimRecords) {
        _claimRecords = new ClaimData[](claimedPlayersForPeriods[_period].length);
        for (uint256 i = 0; i < _claimRecords.length; i++) {
            _claimRecords[i] = claimedPlayersForPeriods[_period][i];
        }
    }

    function isLastPeriodEnded() public view returns (bool) {
        if (periodCount == 0) return true;
        uint256 _currentPeriod = periodCount - 1;
        AllocationRecord memory _currentPeriodRecord = withdrawDefinitions[_currentPeriod];
        return block.timestamp > _currentPeriodRecord.endTime;
    }
}
