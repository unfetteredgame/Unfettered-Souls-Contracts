// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PassHolderSale is Ownable {
    using SafeERC20 for IERC20;

    struct Allocation {
        address addr;
        uint256 firstRoundMaxCap;
        uint256 firstRoundUsedCap;
        uint256 secondRoundUsedCap;
        uint256 secondRoundUserMaxCap;
    }

    IERC20 public paymentToken;
    uint256 public maxCap = 200000 ether;
    // uint256 public secondRoundUserMaxCap = 500 ether;
    uint256 public collectedAmount;
    uint256 public firstRoundStartTime;
    uint256 public firstRoundEndTime;
    uint256 public secondRoundStartTime;
    uint256 public secondRoundEndTime;
    uint256 public _minPurchaseAmount;

    address treasuryAddress;

    mapping(address => Allocation) public allocations;

    error SecondRoundNotStarted();
    error AddressAlreadyAdded();
    error ExceedsAllocation();
    error SaleNotStarted();
    error AlreadyStarted();
    error ExceedsMaxCap();
    error InvalidAmount();
    error AlreadyEnded();
    error NoAllocation();
    error InvalidTime();
    error SaleEnded();

    event BuyTokens(address investor, uint256 amount);

    constructor(
        IERC20 _paymetToken,
        address _treasuryAddress,
        uint256 _firstRoundStartTime,
        uint256 _firstRoundEndTime,
        uint256 _secondRoundStartTime,
        uint256 _secondRoundEndTime,
        uint256 minPurchaseAmount
    ) {
        paymentToken = _paymetToken;
        treasuryAddress = _treasuryAddress;
        _setFirstRoundSchedule(_firstRoundStartTime, _firstRoundEndTime);
        _setSecondRoundSchedule(_secondRoundStartTime, _secondRoundEndTime);
        _minPurchaseAmount = minPurchaseAmount;
    }

    function setTreasuryAddress(address _newAddress) external onlyOwner {
        treasuryAddress = _newAddress;
    }

    function setFirstRoundSchedule(uint256 _startTime, uint256 _endTime) external onlyOwner {
        _setFirstRoundSchedule(_startTime, _endTime);
    }

    function setSecondRoundSchedule(uint256 _startTime, uint256 _endTime) external onlyOwner {
        _setSecondRoundSchedule(_startTime, _endTime);
    }

    function _setFirstRoundSchedule(uint256 _startTime, uint256 _endTime) private onlyOwner {
        // if (firstRoundStartTime != 0 && block.timestamp >= firstRoundStartTime) revert AlreadyStarted();
        // if (firstRoundEndTime != 0 && block.timestamp >= firstRoundEndTime) revert AlreadyEnded();
        if (_startTime >= _endTime) revert InvalidTime();

        firstRoundStartTime = _startTime;
        firstRoundEndTime = _endTime;
    }

    function _setSecondRoundSchedule(uint256 _startTime, uint256 _endTime) private onlyOwner {
        // if (secondRoundStartTime != 0 && block.timestamp >= secondRoundStartTime) revert AlreadyStarted();
        // if (secondRoundEndTime != 0 && block.timestamp >= secondRoundEndTime) revert AlreadyEnded();
        if (_startTime >= _endTime || _startTime <= firstRoundEndTime) revert InvalidTime();

        secondRoundStartTime = _startTime;
        secondRoundEndTime = _endTime;
    }

    function setFirstRoundEndTime(uint256 _endTime) external onlyOwner {
        if (block.timestamp > _endTime || _endTime <= firstRoundStartTime || _endTime >= secondRoundEndTime)
            revert InvalidTime();
        firstRoundEndTime = _endTime;
    }

    function setSecondRoundEndTime(uint256 _endTime) external onlyOwner {
        if (block.timestamp > _endTime || _endTime <= secondRoundStartTime) revert InvalidTime();
        firstRoundEndTime = _endTime;
    }

    function setAllocation(Allocation[] calldata _allocations) external onlyOwner {
        for (uint i = 0; i < _allocations.length; i++) {
            if (allocations[_allocations[i].addr].firstRoundMaxCap > 0) {
                revert AddressAlreadyAdded();
            }
            allocations[_allocations[i].addr] = _allocations[i];
        }
    }

    function setMinPurchaseAmount(uint256 minPurchaseAmount) external onlyOwner {
        _minPurchaseAmount = minPurchaseAmount;
    }

    function buyTokens(uint256 _amountToSpend) external {
        if (block.timestamp < firstRoundStartTime) {
            revert SaleNotStarted();
        } else if (block.timestamp >= firstRoundStartTime && block.timestamp <= firstRoundEndTime) {
            _buyTokens(_amountToSpend);
        } else if (block.timestamp > firstRoundEndTime && block.timestamp < secondRoundStartTime) {
            revert SecondRoundNotStarted();
        } else if (block.timestamp >= secondRoundStartTime && block.timestamp <= secondRoundEndTime) {
            _buyTokensFCFS(_amountToSpend);
        } else {
            revert SaleEnded();
        }
        collectedAmount += _amountToSpend;
        if (collectedAmount > maxCap) revert ExceedsMaxCap();
    }

    function _buyTokens(uint256 _amountToSpend) private {
        if (allocations[msg.sender].firstRoundUsedCap + _amountToSpend < _minPurchaseAmount) revert InvalidAmount();

        if (allocations[msg.sender].firstRoundMaxCap == 0) revert NoAllocation();
        if (allocations[msg.sender].firstRoundUsedCap + _amountToSpend > allocations[msg.sender].firstRoundMaxCap) {
            revert ExceedsAllocation();
        }
        paymentToken.safeTransferFrom(msg.sender, treasuryAddress, _amountToSpend);

        allocations[msg.sender].firstRoundUsedCap += _amountToSpend;
        emit BuyTokens(msg.sender, _amountToSpend);
    }

    function _buyTokensFCFS(uint256 _amountToSpend) private {
        if (allocations[msg.sender].firstRoundMaxCap == 0) revert NoAllocation();
        if (allocations[msg.sender].secondRoundUsedCap + _amountToSpend < _minPurchaseAmount) revert InvalidAmount();

        if (
            allocations[msg.sender].secondRoundUsedCap + _amountToSpend > allocations[msg.sender].secondRoundUserMaxCap
        ) {
            revert ExceedsAllocation();
        }

        paymentToken.safeTransferFrom(msg.sender, treasuryAddress, _amountToSpend);
        allocations[msg.sender].secondRoundUsedCap += _amountToSpend;
        emit BuyTokens(msg.sender, _amountToSpend);
    }
}
