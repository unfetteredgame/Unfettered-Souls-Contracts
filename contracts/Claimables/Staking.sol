// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "../interfaces/IManagers.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {StakeData, IStaking} from "../interfaces/IStaking.sol";

contract Staking is ERC165Storage, IStaking {
    using SafeERC20 for IERC20;

    //State Variables
    IManagers private managers;
    IERC20 public tokenContract;

    uint256 public minimumStakingAmount = 10000 ether;
    uint256 public immutable monthToSecond = 30 days;
    uint256 public immutable yearToSecond = 365 days;
    uint256 public totalStakedAmount;
    uint256 public totalWithdrawnAmount;
    uint256 public totalDistributedReward;
    uint256 public stakeRewardPercentageFor1Month;
    uint256 public stakeRewardPercentageFor3Month;
    uint256 public stakeRewardPercentageFor6Month;
    uint256 public stakeRewardPercentageFor12Month;

    address[] private stakers;

    mapping(address => StakeData[]) public stakes;
    mapping(address => bool) public isStaker;

    bool public paused;

    //Custom Errors
    error AmountMustBeGreaterThanMinimumStakingAmount();
    error StakingNotPausedCurrently();
    error InvalidStakingDuration();
    error StakingPausedCurrently();
    error CanWithdrawNormal();
    error AlreadyWithdrawn();
    error OnlyManagers();
    error EarlyRequest();

    //Events
    event Stake(address indexed sender, uint256 amount, uint256 stakeDate, uint256 releaseDate);
    event Withdraw(address indexed sender, uint256 amount, uint256 stakeDate);
    event EmergencyWithdraw(address indexed sender, uint256 amount, uint256 stakeDate);
    event ChangeStakeAPYRates(
        uint256 newPercentageFor1Month,
        uint256 newPercentageFor3Month,
        uint256 newPercentageFor6Month,
        uint256 newPercentageFor12Month,
        bool isApproved
    );
    event ChangeMinimumAmount(uint256 newAmount, bool isApproved);
    event Paused(address manager);
    event Unpaused(address manager, bool isApproved);

    constructor(
        address _tokenContractAddress,
        address _managersContractAddress,
        uint256 _stakePercentagePer1Month,
        uint256 _stakePercentagePer3Month,
        uint256 _stakePercentagePer6Month,
        uint256 _stakePercentagePer12Month
    ) {
        tokenContract = IERC20(_tokenContractAddress);
        managers = IManagers(_managersContractAddress);
        stakeRewardPercentageFor1Month = _stakePercentagePer1Month;
        stakeRewardPercentageFor3Month = _stakePercentagePer3Month;
        stakeRewardPercentageFor6Month = _stakePercentagePer6Month;
        stakeRewardPercentageFor12Month = _stakePercentagePer12Month;

        _registerInterface(type(IStaking).interfaceId);
    }

    //Modifiers
    modifier onlyManager() {
        if (!managers.isManager(msg.sender)) {
            revert OnlyManagers();
        }
        _;
    }

    modifier whenNotPaused() {
        if (paused) {
            revert StakingPausedCurrently();
        }
        _;
    }

    //Write Functions
    //Managers Function
    function changeStakeAPYRates(
        uint256 _newPercentageFor1Month,
        uint256 _newPercentageFor3Month,
        uint256 _newPercentageFor6Month,
        uint256 _newPercentageFor12Month
    ) external onlyManager {
        string memory _title = "Change Stake APY Rates";
        bytes memory _encodedValues = abi.encode(
            _newPercentageFor1Month,
            _newPercentageFor3Month,
            _newPercentageFor6Month,
            _newPercentageFor12Month
        );
        managers.approveTopic(_title, _encodedValues);

        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            stakeRewardPercentageFor1Month = _newPercentageFor1Month;
            stakeRewardPercentageFor3Month = _newPercentageFor3Month;
            stakeRewardPercentageFor6Month = _newPercentageFor6Month;
            stakeRewardPercentageFor12Month = _newPercentageFor12Month;

            managers.deleteTopic(_title);
        }
        emit ChangeStakeAPYRates(
            _newPercentageFor1Month,
            _newPercentageFor3Month,
            _newPercentageFor6Month,
            _newPercentageFor12Month,
            _isApproved
        );
    }

    //Managers Function
    function changeMinimumStakingAmount(uint256 _newAmount) external onlyManager {
        string memory _title = "Change Emergency Exit Penalty Rate";
        bytes memory _encodedValues = abi.encode(_newAmount);
        managers.approveTopic(_title, _encodedValues);

        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            minimumStakingAmount = _newAmount;

            managers.deleteTopic(_title);
        }
        emit ChangeMinimumAmount(_newAmount, _isApproved);
    }

    function stake(uint256 _amount, uint8 _monthToStake) external whenNotPaused {
        uint256 _rewardPercentage;
        if (_monthToStake == 1) {
            _rewardPercentage = stakeRewardPercentageFor1Month;
        } else if (_monthToStake == 3) {
            _rewardPercentage = stakeRewardPercentageFor3Month;
        } else if (_monthToStake == 6) {
            _rewardPercentage = stakeRewardPercentageFor6Month;
        } else if (_monthToStake == 12) {
            _rewardPercentage = stakeRewardPercentageFor12Month;
        } else {
            revert InvalidStakingDuration();
        }

        if (_amount < minimumStakingAmount) {
            revert AmountMustBeGreaterThanMinimumStakingAmount();
        }

        tokenContract.safeTransferFrom(msg.sender, address(this), _amount);
        //Calculations of stakePercentage and release dates for different time ranges

        StakeData memory _stakeDetails = StakeData({
            amount: _amount,
            stakeDate: block.timestamp,
            percentage: _rewardPercentage,
            monthToStake: _monthToStake,
            releaseDate: block.timestamp + (_monthToStake * monthToSecond),
            withdrawn: false,
            emergencyWithdrawn: false,
            withdrawTime: 0
        });

        //stakes array for access to my stakeDetails array
        stakes[msg.sender].push(_stakeDetails);
        totalStakedAmount += _amount;

        if (!isStaker[msg.sender]) {
            stakers.push(msg.sender);
            isStaker[msg.sender] = true;
        }

        emit Stake(msg.sender, _amount, _stakeDetails.stakeDate, _stakeDetails.releaseDate);
    }

    function emergencyWithdrawStake(uint256 _stakeIndex) external {
        if (stakes[msg.sender][_stakeIndex].withdrawn) {
            revert AlreadyWithdrawn();
        }

        if (block.timestamp >= stakes[msg.sender][_stakeIndex].releaseDate) {
            revert CanWithdrawNormal();
        }
        stakes[msg.sender][_stakeIndex].withdrawn = true;
        stakes[msg.sender][_stakeIndex].emergencyWithdrawn = true;
        stakes[msg.sender][_stakeIndex].withdrawTime = block.timestamp;

        (uint256 _totalAmount, uint256 _emergencyExitPenalty) = fetchStakeRewardForAddress(msg.sender, _stakeIndex);

        uint256 _amountAfterPenalty = _totalAmount - _emergencyExitPenalty;

        tokenContract.safeTransfer(msg.sender, _amountAfterPenalty);

        totalWithdrawnAmount += _amountAfterPenalty;
        totalDistributedReward += _amountAfterPenalty > stakes[msg.sender][_stakeIndex].amount
            ? (_amountAfterPenalty - stakes[msg.sender][_stakeIndex].amount)
            : 0;
        totalStakedAmount -= stakes[msg.sender][_stakeIndex].amount;

        emit EmergencyWithdraw(msg.sender, _amountAfterPenalty, block.timestamp);
    }

    function withdrawStake(uint256 _stakeIndex) external {
        if (stakes[msg.sender][_stakeIndex].withdrawn) {
            revert AlreadyWithdrawn();
        }

        if (block.timestamp < stakes[msg.sender][_stakeIndex].releaseDate) {
            revert EarlyRequest();
        }
        stakes[msg.sender][_stakeIndex].withdrawn = true;
        stakes[msg.sender][_stakeIndex].withdrawTime = block.timestamp;

        (uint256 _totalAmount, ) = fetchStakeRewardForAddress(msg.sender, _stakeIndex);

        tokenContract.safeTransfer(msg.sender, _totalAmount);

        totalStakedAmount -= stakes[msg.sender][_stakeIndex].amount;
        totalWithdrawnAmount += _totalAmount;
        totalDistributedReward += _totalAmount - stakes[msg.sender][_stakeIndex].amount;

        emit Withdraw(msg.sender, _totalAmount, block.timestamp);
    }

    function pause() external onlyManager whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    //Managers Function
    function unpause() external onlyManager {
        if (!paused) {
            revert StakingNotPausedCurrently();
        }
        string memory _title = "Unpause Staking Contract";
        bytes memory _encodedValues = abi.encode(true);
        managers.approveTopic(_title, _encodedValues);

        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            paused = false;
            managers.deleteTopic(_title);
        }
        emit Unpaused(msg.sender, _isApproved);
    }

    //Read Functions
    function getTotalBalance() public view returns (uint256) {
        return tokenContract.balanceOf(address(this));
    }

    function fetchStakeDataForAddress(address _address) public view returns (StakeData[] memory) {
        return stakes[_address];
    }

    function fetchOwnStakeData() public view returns (StakeData[] memory) {
        return fetchStakeDataForAddress(msg.sender);
    }

    function fetchStakeRewardForAddress(
        address _address,
        uint256 _stakeIndex
    ) public view returns (uint256 _totalAmount, uint256 _penaltyAmount) {
        bool _hasPenalty = block.timestamp < stakes[_address][_stakeIndex].releaseDate;

        uint256 rewardEarningEndTime = _hasPenalty ? block.timestamp : stakes[_address][_stakeIndex].releaseDate;

        uint256 _dateDiff = rewardEarningEndTime - stakes[_address][_stakeIndex].stakeDate;

        _totalAmount =
            stakes[_address][_stakeIndex].amount +
            ((stakes[_address][_stakeIndex].amount * stakes[_address][_stakeIndex].percentage * _dateDiff) /
                (yearToSecond * 100 ether));

        if (_hasPenalty) {
            uint256 actualPenaltyRate = stakes[msg.sender][_stakeIndex].percentage -
                ((stakes[msg.sender][_stakeIndex].percentage * _dateDiff) /
                    (stakes[msg.sender][_stakeIndex].monthToStake * monthToSecond));

            _penaltyAmount = (_totalAmount * actualPenaltyRate) / 100 ether;
        }
    }

    function fetchStakeReward(uint256 _stakeIndex) public view returns (uint256 _totalAmount, uint256 _penaltyAmount) {
        (_totalAmount, _penaltyAmount) = fetchStakeRewardForAddress(msg.sender, _stakeIndex);
    }

    function fetchActiveStakers() public view returns (address[] memory _resultArray) {
        uint256 _activeStakerCount = 0;
        for (uint256 s = 0; s < stakers.length; s++) {
            for (uint256 i = 0; i < stakes[stakers[s]].length; i++) {
                if (!stakes[stakers[s]][i].withdrawn) {
                    _activeStakerCount++;
                    break;
                }
            }
        }

        if (_activeStakerCount > 0) {
            _resultArray = new address[](_activeStakerCount);
            uint256 _currentIndex = 0;
            for (uint256 s = 0; s < stakers.length; s++) {
                for (uint256 i = 0; i < stakes[stakers[s]].length; i++) {
                    if (!stakes[stakers[s]][i].withdrawn) {
                        _resultArray[_currentIndex] = stakers[s];
                        _currentIndex++;
                        break;
                    }
                }
            }
        }

        return _resultArray;
    }

    function fetchAllStakers() public view returns (address[] memory) {
        return stakers;
    }
}
