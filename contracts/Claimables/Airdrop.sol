// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IManagers.sol";
import "../interfaces/IERC20Extended.sol";
import {ClaimData, IAirdrop} from "../interfaces/IAirdrop.sol";

contract Airdrop is IAirdrop, ERC165Storage, Pausable {
    using SafeERC20 for IERC20;

    //Structs
    struct AirdropRecord {
        bytes32 merkleRootHash;
        uint256 totalAmount;
        uint256 startTime;
        uint256 endTime;
        uint256 remainingAmount;
        uint256 rewardOwnerCount;
    }

    //Storage Variables
    IManagers private managers;
    AirdropRecord[] public airdropRecords;

    uint256 public airdropRecordCount;

    address public soulsTokenAddress;
    address public airdropVaultAddress;

    mapping(uint256 => mapping(address => bool)) public claimRecords;
    mapping(uint256 => ClaimData[]) claimedWalletsForPeriods;

    //Custom Errors
    error NotEnoughBalanceInAirdropContract();
    error EndTimeMustBeLaterThanStartTime();
    error StartTimeMustBeInTheFuture();
    error AirdropPeriodNotStarted();
    error ThereIsActiveAirdrop();
    error AirdropPeriodEnded();
    error InvalidMerkleRoot();
    error ThereIsNoAirdrop();
    error ZeroTotalAmount();
    error NoActiveAirdrop();
    error AlreadyClaimed();
    error NoAllocation();
    error OnlyManagers();

    //Events
    event CreateAirdrop(
        address manager,
        bytes32 merkleRootHash,
        uint256 totalAmount,
        uint256 startTime,
        uint256 endTime,
        bool isApproved
    );
    event CancelAirdrop(
        address manager,
        uint256 airdropPeriod,
        address airdropVaultAddress,
        uint256 refundAmount,
        bool isApproved
    );
    event Claim(address _player, uint256 _amount);
    event RefundToVault(address manager, address airdropVaultAddress, uint256 refundAmount, bool isApproved);
    event Unpause(address manager, bool isApproved);
    event Pause();

    constructor(address _airdropVaultAddress, address _managersAddress, address _soulsTokenAddress) {
        managers = IManagers(_managersAddress);
        soulsTokenAddress = _soulsTokenAddress;
        airdropVaultAddress = _airdropVaultAddress;
        _registerInterface(type(IAirdrop).interfaceId);
    }

    //Modifiers
    modifier onlyManager() {
        if (!managers.isManager(msg.sender)) {
            revert OnlyManagers();
        }
        _;
    }

    //Write Functions

    //Managers Function
    function createNewAirdrop(
        bytes32 _merkleRootHash,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _rewardOwnerCount
    ) external onlyManager {
        if (_merkleRootHash.length == 0) {
            revert InvalidMerkleRoot();
        }
        if (_startTime <= block.timestamp) {
            revert StartTimeMustBeInTheFuture();
        }
        if (_endTime <= _startTime) {
            revert EndTimeMustBeLaterThanStartTime();
        }

        if (_totalAmount == 0) {
            revert ZeroTotalAmount();
        }
        if (IERC20(soulsTokenAddress).balanceOf(address(this)) < _totalAmount) {
            revert NotEnoughBalanceInAirdropContract();
        }

        string memory _title = "Create new airdrop";
        bytes memory _encodedValues = abi.encode(
            _merkleRootHash,
            _totalAmount,
            _startTime,
            _endTime,
            _rewardOwnerCount
        );
        managers.approveTopic(_title, _encodedValues);

        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            airdropRecords.push(
                AirdropRecord({
                    merkleRootHash: _merkleRootHash,
                    totalAmount: _totalAmount,
                    startTime: _startTime,
                    endTime: _endTime,
                    remainingAmount: _totalAmount,
                    rewardOwnerCount: _rewardOwnerCount
                })
            );
            airdropRecordCount++;
            managers.deleteTopic(_title);
        }

        emit CreateAirdrop(msg.sender, _merkleRootHash, _totalAmount, _startTime, _endTime, _isApproved);
    }

    //Managers Function
    function cancelAirdrop() external onlyManager {
        if (airdropRecordCount == 0) {
            revert ThereIsNoAirdrop();
        }
        AirdropRecord storage _currentAirdropRecord = airdropRecords[airdropRecordCount - 1];

        if (_currentAirdropRecord.endTime < block.timestamp) {
            revert AirdropPeriodEnded();
        }
        string memory _title = "Cancel Airdrop";
        bytes memory _encodedValues = abi.encode(airdropRecordCount - 1);
        managers.approveTopic(_title, _encodedValues);
        IERC20 _soulsToken = IERC20(soulsTokenAddress);
        uint256 _balance = _soulsToken.balanceOf(address(this));

        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            _currentAirdropRecord.merkleRootHash = 0x0;
            _currentAirdropRecord.endTime = block.timestamp;
            _soulsToken.safeTransfer(airdropVaultAddress, _balance);
            managers.deleteTopic(_title);
        }

        emit CancelAirdrop(msg.sender, airdropRecordCount - 1, airdropVaultAddress, _balance, _isApproved);
    }

    //Managers Function
    function refundToAirdropVault() external onlyManager {
        AirdropRecord memory _currentAirdropRecord = airdropRecords[airdropRecordCount - 1];
        if (_currentAirdropRecord.startTime < block.timestamp && _currentAirdropRecord.endTime > block.timestamp) {
            revert ThereIsActiveAirdrop();
        }
        string memory _title = "Refund Tokens To Airdrop Vault";
        bytes memory _encodedValues = abi.encode(airdropVaultAddress);
        managers.approveTopic(_title, _encodedValues);
        IERC20 _soulsToken = IERC20(soulsTokenAddress);
        uint256 _balance = _soulsToken.balanceOf(address(this));

        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            IERC20(soulsTokenAddress).safeTransfer(airdropVaultAddress, _balance);
            managers.deleteTopic(_title);
        }

        emit RefundToVault(msg.sender, airdropVaultAddress, _balance, _isApproved);
    }

    function claimTokens(uint256 _amount, bytes32[] calldata _merkleProof) external whenNotPaused {
        if (airdropRecordCount == 0) {
            revert NoActiveAirdrop();
        }
        uint256 _airdropPeriod = airdropRecordCount - 1;
        AirdropRecord storage _currentAirdropRecord = airdropRecords[_airdropPeriod];
        if (block.timestamp < _currentAirdropRecord.startTime) {
            revert AirdropPeriodNotStarted();
        }
        if (block.timestamp >= _currentAirdropRecord.endTime) {
            revert AirdropPeriodEnded();
        }

        bytes32 _leaf = keccak256(abi.encodePacked(msg.sender, _amount, _airdropPeriod));

        if (!MerkleProof.verifyCalldata(_merkleProof, _currentAirdropRecord.merkleRootHash, _leaf)) {
            revert NoAllocation();
        }

        if (claimRecords[_airdropPeriod][msg.sender]) {
            revert AlreadyClaimed();
        }
        claimRecords[_airdropPeriod][msg.sender] = true;
        claimedWalletsForPeriods[_airdropPeriod].push(
            ClaimData({walletAddress: msg.sender, amount: _amount, time: block.timestamp})
        );
        _currentAirdropRecord.remainingAmount -= _amount;
        IERC20 _soulsToken = IERC20(soulsTokenAddress);
        _soulsToken.safeTransfer(msg.sender, _amount);
        emit Claim(msg.sender, _amount);
    }

    function pause() external onlyManager whenNotPaused {
        _pause();
        emit Pause();
    }

    //Managers function
    function unpause() external onlyManager whenPaused {
        string memory _title = "Unpause Airdrop claims";
        bytes memory _encodedValues = abi.encode(true);
        managers.approveTopic(_title, _encodedValues);

        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            _unpause();
            managers.deleteTopic(_title);
        }
        emit Unpause(msg.sender, _isApproved);
    }

    //Read Functions
    function getClaimRecords(uint256 _period) public view returns (ClaimData[] memory _claimRecords) {
        _claimRecords = new ClaimData[](claimedWalletsForPeriods[_period].length);
        for (uint256 i = 0; i < _claimRecords.length; i++) {
            _claimRecords[i] = claimedWalletsForPeriods[_period][i];
        }
    }
}
