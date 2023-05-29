// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./Vault.sol";
import "../Claimables/WithdrawClaim.sol";
import "../interfaces/IPancakeFactory.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IWithdrawClaim.sol";

contract PlayToEarnVault is Vault, Pausable {
    using SafeERC20 for IERC20;
    using ERC165Checker for address;

    //Storage Variables
    address public claimContractAddress;
    address public authorizedAddress;

    uint256 public lastDistributionTime;
    uint256 public intervalBetweenDistributions = 7 days;
    uint256 public distributionOffset = 1 days;
    uint256 public withdrawMaxLimit = 5000 ether;
    uint256 public withdrawMinLimit = 1000 ether;

    mapping(address => mapping(string => uint256)) public depositRecords;

    //Custom Errors
    error DistributionOffsetMustBeLessThenDuration();
    error Use_depositToClaimContract_function();
    error NotEnoughBalanceWaitUntilNextVesting();
    error NotReachedNextDistributionTime();
    error InvalidWithdrawClaimContract();
    error ValueMustBeGreaterThanZero();
    error TrasactionAlreadyDeposited();
    error InvalidLimitAmounts();
    error AmountCannotBeZero();
    error TransferFailed();
    error NotAuthorized();

    //Events
    event PlayerDeposit(address player, string PlayFabId, string playfabTxId, uint256 amount);
    event DepositToClaimContract(address claimContractAddress, uint256 amount);
    event SetWithdrawClaimContractAddress(address newAddress, address oldAddress, bool isApproved);
    event SetWithdrawLimits(uint256 minLimit, uint256 maxLimit, bool isApproved);
    event SetWithdrawDistributionInterval(
        uint256 durationInMinutes,
        uint256 distributionOffsetInMinutes,
        bool isApproved
    );
    event SetAuthorizedAddress(address newAddress, address oldAddress, bool isApproved);
    event Unpause(bool isApproved);
    event Pause();

    constructor(
        address _mainVaultAddress,
        address _soulsTokenAddress,
        address _managersAddress,
        address _authorizedAddress,
        address _withdrawClaimAuthorizedAddress
    ) Vault("Play To Earn Vault", _mainVaultAddress, _soulsTokenAddress, _managersAddress) {
        authorizedAddress = _authorizedAddress;
        claimContractAddress = address(
            new WithdrawClaim(_managersAddress, _soulsTokenAddress, _withdrawClaimAuthorizedAddress)
        );
    }

    // Write Fuctions

    //Managers function
    function setClaimContractAddress(address _newAddress) external onlyManager {
        if (!_newAddress.supportsInterface(type(IWithdrawClaim).interfaceId)) {
            revert InvalidWithdrawClaimContract();
        }
        string memory _title = "Set Withdraw Claim Contract Address";

        bytes memory _encodedValues = abi.encode(_newAddress);
        managers.approveTopic(_title, _encodedValues);

        address _currentValue = claimContractAddress;
        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            claimContractAddress = _newAddress;
            managers.deleteTopic(_title);
        }

        emit SetWithdrawClaimContractAddress(_newAddress, _currentValue, _isApproved);
    }

    //Managers function
    function setWithdrawLimits(uint256 _minLimit, uint256 _maxLimit) external onlyManager {
        if (_minLimit == 0) {
            revert ValueMustBeGreaterThanZero();
        }
        if (_maxLimit <= _minLimit) {
            revert InvalidLimitAmounts();
        }

        string memory _title = "Set withdraw limits";

        bytes memory _encodedValues = abi.encode(_minLimit, _maxLimit);
        managers.approveTopic(_title, _encodedValues);

        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            withdrawMinLimit = _minLimit;
            withdrawMaxLimit = _maxLimit;
            managers.deleteTopic(_title);
        }

        emit SetWithdrawLimits(_minLimit, _maxLimit, _isApproved);
    }

    //Managers function
    function setIntervalBetweenDistributions(
        uint256 _durationInMinutes,
        uint256 _distributionOffsetInMinutes
    ) external onlyManager {
        if (_durationInMinutes == 0 || _distributionOffsetInMinutes == 0) {
            revert ValueMustBeGreaterThanZero();
        }
        if (_distributionOffsetInMinutes >= _durationInMinutes) {
            revert DistributionOffsetMustBeLessThenDuration();
        }

        string memory _title = "Set withdraw distribution Interval";

        bytes memory _encodedValues = abi.encode(_durationInMinutes, _distributionOffsetInMinutes);
        managers.approveTopic(_title, _encodedValues);

        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            intervalBetweenDistributions = _durationInMinutes * 1 minutes;
            distributionOffset = _distributionOffsetInMinutes * 1 minutes;
            managers.deleteTopic(_title);
        }

        emit SetWithdrawDistributionInterval(_durationInMinutes, _distributionOffsetInMinutes, _isApproved);
    }

    //Managers function
    function setAuthorizedAddress(address _newAddress) external onlyManager {
        if (_newAddress == address(0)) {
            revert ZeroAddress();
        }

        string memory _title = "Set play to earn service address";

        bytes memory _encodedValues = abi.encode(_newAddress);
        managers.approveTopic(_title, _encodedValues);

        bool _isApproved = managers.isApproved(_title, _encodedValues);
        address _currentValue = authorizedAddress;
        if (_isApproved) {
            authorizedAddress = _newAddress;
            managers.deleteTopic(_title);
        }

        emit SetAuthorizedAddress(_newAddress, _currentValue, _isApproved);
    }

    function pause() external onlyManager whenNotPaused {
        _pause();
        emit Pause();
    }

    //Managers function
    function unpause() external onlyManager whenPaused {
        string memory _title = "Unpause play to earn vault functions";
        bytes memory _encodedValues = abi.encode(true);
        managers.approveTopic(_title, _encodedValues);

        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            _unpause();
            managers.deleteTopic(_title);
        }
        emit Unpause(_isApproved);
    }

    function withdrawTokens(address[] calldata, uint256[] calldata) external view override onlyManager {
        revert Use_depositToClaimContract_function();
    }

    function playerDepositTokensToGame(
        uint256 _amount,
        string memory _playfabId,
        string memory _playfabTxId
    ) external whenNotPaused {
        if (_amount == 0) {
            revert AmountCannotBeZero();
        }

        if (depositRecords[msg.sender][_playfabTxId] > 0) {
            revert TrasactionAlreadyDeposited();
        }

        depositRecords[msg.sender][_playfabTxId] = _amount;

        IERC20(soulsTokenAddress).safeTransferFrom(msg.sender, address(this), _amount);
        emit PlayerDeposit(msg.sender, _playfabId, _playfabTxId, _amount);
    }

    function depositToClaimContract(uint256 _requiredAmount, address _nextAuthorizedAddress) external whenNotPaused {
        if (msg.sender != authorizedAddress) {
            revert NotAuthorized();
        }

        if (_nextAuthorizedAddress == address(0)) {
            revert ZeroAddress();
        }

        uint256 _nextDistributionTime = lastDistributionTime + intervalBetweenDistributions - distributionOffset;
        if (_nextDistributionTime > block.timestamp) {
            revert NotReachedNextDistributionTime();
        }

        lastDistributionTime = getNextPeriodStartTime();
        authorizedAddress = _nextAuthorizedAddress;
        IERC20 _soulsToken = IERC20(soulsTokenAddress);
        uint256 _balance = _soulsToken.balanceOf(address(this));

        if (_requiredAmount > _balance) {
            //Needs to release new vesting
            currentVestingIndex++;
            if (tokenVestings[currentVestingIndex - 1].unlockTime < block.timestamp) {
                tokenVestings[currentVestingIndex - 1].released = true;
                _soulsToken.safeTransferFrom(
                    mainVaultAddress,
                    address(this),
                    tokenVestings[currentVestingIndex - 1].amount
                );
                emit ReleaseVesting(block.timestamp, currentVestingIndex - 1);
            } else {
                revert NotEnoughBalanceWaitUntilNextVesting();
            }
        }

        _soulsToken.safeTransfer(claimContractAddress, _requiredAmount);

        emit DepositToClaimContract(claimContractAddress, _requiredAmount);
    }

    // Read Fuctions
    function isReadyForNextDistribution() public view returns (bool) {
        return block.timestamp >= lastDistributionTime + intervalBetweenDistributions - distributionOffset;
    }

    function getNextPeriodStartTime() public view returns (uint256 _startTime) {
        _startTime = block.timestamp + distributionOffset;
        if (lastDistributionTime + intervalBetweenDistributions > block.timestamp) {
            _startTime = lastDistributionTime + intervalBetweenDistributions;
        }
    }
}
