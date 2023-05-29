// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IManagers.sol";

contract Vault {
    using SafeERC20 for IERC20;

    //Structs
    struct VestingInfo {
        uint256 amount;
        uint256 unlockTime;
        bool released;
    }

    //Storage Variables
    IManagers immutable managers;
    address public immutable soulsTokenAddress;
    address public immutable mainVaultAddress;

    uint256 public currentVestingIndex;

    string public vaultName;

    VestingInfo[] public tokenVestings;

    //Custom Errors
    error OnlyOnceFunctionWasCalledBefore();
    error WaitForNextVestingReleaseDate();
    error NotAuthorized_ONLY_MAINVAULT();
    error NotAuthorized_ONLY_MANAGERS();
    error DifferentParametersLength();
    error InvalidFrequency();
    error NotEnoughAmount();
    error NoMoreVesting();
    error ZeroAmount();
    error ZeroAddress();

    //Events
    event Withdraw(uint256 date, uint256 amount, bool isApproved);
    event ReleaseVesting(uint256 date, uint256 vestingIndex);

    constructor(
        string memory _vaultName,
        address _mainVaultAddress,
        address _soulsTokenAddress,
        address _managersAddress
    ) {
        if (_mainVaultAddress == address(0) || _soulsTokenAddress == address(0) || _managersAddress == address(0)) {
            revert ZeroAddress();
        }
        vaultName = _vaultName;
        mainVaultAddress = _mainVaultAddress;
        soulsTokenAddress = _soulsTokenAddress;
        managers = IManagers(_managersAddress);
    }

    //Modifiers
    modifier onlyOnce() {
        if (tokenVestings.length > 0) {
            revert OnlyOnceFunctionWasCalledBefore();
        }
        _;
    }

    modifier onlyMainVault() {
        if (msg.sender != mainVaultAddress) {
            revert NotAuthorized_ONLY_MAINVAULT();
        }
        _;
    }

    modifier onlyManager() {
        if (!managers.isManager(msg.sender)) {
            revert NotAuthorized_ONLY_MANAGERS();
        }
        _;
    }

    // Write Functions
    function createVestings(
        uint256 _totalAmount,
        uint256 _initialRelease,
        uint256 _initialReleaseDate,
        uint256 _countOfVestings,
        uint256 _vestingStartDate,
        uint256 _releaseFrequencyInDays
    ) public virtual onlyOnce onlyMainVault {
        if (_totalAmount == 0) {
            revert ZeroAmount();
        }
        if (_countOfVestings > 0 && _releaseFrequencyInDays == 0) {
            revert InvalidFrequency();
        }

        uint256 _amountUsed = 0;

        if (_initialRelease > 0) {
            tokenVestings.push(
                VestingInfo({amount: _initialRelease, unlockTime: _initialReleaseDate, released: false})
            );
            _amountUsed += _initialRelease;
        }
        uint256 releaseFrequency = _releaseFrequencyInDays * 1 days;

        if (_countOfVestings > 0) {
            uint256 _vestingAmount = (_totalAmount - _initialRelease) / _countOfVestings;

            for (uint256 i = 0; i < _countOfVestings; i++) {
                if (i == _countOfVestings - 1) {
                    _vestingAmount = _totalAmount - _amountUsed;
                }
                tokenVestings.push(
                    VestingInfo({
                        amount: _vestingAmount,
                        unlockTime: _vestingStartDate + (i * releaseFrequency),
                        released: false
                    })
                );
                _amountUsed += _vestingAmount;
            }
        }
    }

    //Managers function
    function withdrawTokens(address[] calldata _receivers, uint256[] calldata _amounts) external virtual onlyManager {
        _withdrawTokens(_receivers, _amounts);
    }

    function _withdrawTokens(
        address[] memory _receivers,
        uint256[] memory _amounts
    ) internal returns (bool _isApproved) {
        if (_receivers.length != _amounts.length) {
            revert DifferentParametersLength();
        }

        uint256 _totalAmount = 0;
        for (uint256 a = 0; a < _amounts.length; a++) {
            if (_amounts[a] == 0) {
                revert ZeroAmount();
            }

            _totalAmount += _amounts[a];
        }

        uint256 _balance = IERC20(soulsTokenAddress).balanceOf(address(this));
        uint256 _amountWillBeReleased = 0;
        if (_totalAmount > _balance) {
            if (currentVestingIndex >= tokenVestings.length) {
                revert NoMoreVesting();
            }

            if (block.timestamp < tokenVestings[currentVestingIndex].unlockTime) {
                revert WaitForNextVestingReleaseDate();
            }

            for (uint256 v = currentVestingIndex; v < tokenVestings.length; v++) {
                if (tokenVestings[v].unlockTime > block.timestamp) break;
                _amountWillBeReleased += tokenVestings[v].amount;
            }

            if (_amountWillBeReleased + _balance < _totalAmount) {
                revert NotEnoughAmount();
            }
        }

        string memory _title = string.concat("Withdraw Tokens From ", vaultName);

        bytes memory _encodedValues = abi.encode(_receivers, _amounts);
        managers.approveTopic(_title, _encodedValues);
        _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            IERC20 _soulsToken = IERC20(soulsTokenAddress);
            if (_totalAmount > _balance) {
                //Needs to release new vesting

                for (uint256 v = currentVestingIndex; v < tokenVestings.length; v++) {
                    if (tokenVestings[v].unlockTime < block.timestamp) {
                        tokenVestings[v].released = true;
                        emit ReleaseVesting(block.timestamp, v);
                        currentVestingIndex++;
                    }
                }

                if (_amountWillBeReleased > 0) {
                    _soulsToken.safeTransferFrom(mainVaultAddress, address(this), _amountWillBeReleased);
                }
            }

            for (uint256 r = 0; r < _receivers.length; r++) {
                address _receiver = _receivers[r];
                uint256 _amount = _amounts[r];

                _soulsToken.safeTransfer(_receiver, _amount);
            }
            managers.deleteTopic(_title);
        }

        emit Withdraw(block.timestamp, _totalAmount, _isApproved);
    }

    //Read Functions
    function getVestingData() public view returns (VestingInfo[] memory) {
        return tokenVestings;
    }

    function getAvailableAmountForWithdraw() public view returns (uint256 _amount) {
        _amount = IERC20(soulsTokenAddress).balanceOf(address(this));
        for (uint256 v = currentVestingIndex; v < tokenVestings.length; v++) {
            if (tokenVestings[v].unlockTime > block.timestamp) break;
            _amount += tokenVestings[v].amount;
        }
    }
}
