// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IManagers.sol";
import {TokenReward, ICrowdfunding} from "../interfaces/ICrowdfunding.sol";

contract Crowdfunding is ERC165Storage, Ownable {
    using SafeERC20 for IERC20;
    //Structs
    struct Investor {
        uint256 totalAmount;
        uint256 vestingCount;
        uint256 currentVestingIndex;
        uint256 blacklistDate;
    }

    //State Variables
    IManagers private immutable managers;
    IERC20 public immutable soulsToken;

    uint256 public immutable totalCap;
    uint256 public totalRewardAmount;
    uint256 public totalClaimedAmount;
    uint256 public freeBalance;
    address[] public investorList;

    string public crowdfundingType;

    mapping(address => TokenReward[]) public tokenRewards;
    mapping(address => Investor) public investors;

    // Custom Errors
    error AddressIsBlacklisted(address rewardOwner);
    error InvestorAlreadyAdded(address rewardOwner);
    error VestingIndexShouldBeEqualToCurrentVestingIndex();
    error ReleaseDateIsBeforeAdvanceReleaseDate();
    error AdvanceReleaseDateIsInThePast();
    error TotalRewardExceedsTotalCap();
    error TotalCapCannotBeZero();
    error RewardOwnerNotFound();
    error InvalidVestingIndex();
    error RewardIsDeactivated();
    error AlreadyBlacklisted();
    error AlreadyDeactive();
    error AlreadyClaimed();
    error NotBlacklisted();
    error AlreadyActive();
    error OnlyManagers();
    error EarlyRequest();
    error ZeroAddress();
    error InvalidData();

    //Events
    event AddRewards(
        address manager,
        address[] rewardOwners,
        uint256[] advanceAmountPerAddress,
        uint256[] totalOfVestings,
        uint256 vestingCount,
        uint256 advanceReleaseDate,
        uint256 vestingStartDate,
        address tokenHolder,
        bool isApproved
    );
    event DeactivateVesting(
        address manager,
        address rewardOwner,
        uint8[] vestingIndexes,
        string description,
        bool isApproved
    );
    event ActivateVesting(
        address manager,
        address rewardOwner,
        uint8[] vestingIndexes,
        string description,
        bool isApproved
    );
    event AddToBlacklist(address manager, address rewardOwner, string description, bool isApproved);
    event RemoveFromBlacklist(address manager, address rewardOwner, string description, bool isApproved);

    event Claim(address rewardOwner, uint256 vestingIndex, uint256 amount);

    constructor(
        string memory _CrowdfundingType,
        uint256 _totalCap,
        address _soulsTokenAddress,
        address _managersAddress
    ) {
        if (_totalCap == 0) {
            revert TotalCapCannotBeZero();
        }
        if (_soulsTokenAddress == address(0) || _managersAddress == address(0)) {
            revert ZeroAddress();
        }
        crowdfundingType = _CrowdfundingType;
        soulsToken = IERC20(_soulsTokenAddress);
        managers = IManagers(_managersAddress);
        totalCap = _totalCap;
        _registerInterface(type(ICrowdfunding).interfaceId);
    }

    //Modifiers
    modifier ifNotBlacklisted(uint256 _time) {
        if (isInBlacklist(msg.sender, _time)) {
            revert AddressIsBlacklisted(msg.sender);
        }
        _;
    }

    modifier onlyManager() {
        if (!managers.isManager(msg.sender)) {
            revert OnlyManagers();
        }
        _;
    }

    //Write functions

    //Managers function
    function addRewards(
        address[] memory _rewardOwners,
        uint256[] memory _advanceAmountPerAddress,
        uint256[] memory _totalOfVestings, //excluding advance amount
        uint256 _vestingCount, // excluding advance payment
        uint256 _advanceReleaseDate,
        uint256 _vestingStartDate,
        address _crowdfundingVault
    ) external onlyManager {
        if (_crowdfundingVault == address(0)) {
            revert ZeroAddress();
        }
        if (
            _rewardOwners.length != _advanceAmountPerAddress.length || _rewardOwners.length != _totalOfVestings.length
        ) {
            revert InvalidData();
        }

        if (_advanceReleaseDate < block.timestamp) {
            revert AdvanceReleaseDateIsInThePast();
        }
        if (_vestingCount > 0 && _vestingStartDate <= _advanceReleaseDate) {
            revert ReleaseDateIsBeforeAdvanceReleaseDate();
        }

        uint256 _totalAmount = 0;

        for (uint256 r = 0; r < _rewardOwners.length; r++) {
            address _rewardOwner = _rewardOwners[r];
            if (investors[_rewardOwner].totalAmount > 0) {
                revert InvestorAlreadyAdded(_rewardOwner);
            }
            if (isInBlacklist(_rewardOwner, block.timestamp)) {
                revert AddressIsBlacklisted(_rewardOwner);
            }
            uint256 _investorTotalAmount = _advanceAmountPerAddress[r] + _totalOfVestings[r];
            _totalAmount += _investorTotalAmount;
        }

        if (totalRewardAmount + _totalAmount > totalCap) {
            revert TotalRewardExceedsTotalCap();
        }

        string memory _title = "Add New Rewards";
        bytes memory _encodedValues = abi.encode(
            _rewardOwners,
            _advanceAmountPerAddress,
            _totalOfVestings,
            _vestingCount,
            _advanceReleaseDate,
            _vestingStartDate,
            _crowdfundingVault
        );

        managers.approveTopic(_title, _encodedValues);
        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            _addRewards(
                _rewardOwners,
                _advanceAmountPerAddress,
                _totalOfVestings,
                _vestingCount,
                _advanceReleaseDate,
                _vestingStartDate,
                _crowdfundingVault
            );

            managers.deleteTopic(_title);
        }
        emit AddRewards(
            msg.sender,
            _rewardOwners,
            _advanceAmountPerAddress,
            _totalOfVestings,
            _vestingCount,
            _advanceReleaseDate,
            _vestingStartDate,
            _crowdfundingVault,
            _isApproved
        );
    }

    function _addRewards(
        address[] memory _rewardOwners,
        uint256[] memory _advanceAmountPerAddress,
        uint256[] memory _totalOfVestings, //excluding advance amount
        uint256 _vestingCount, // excluding advance payment
        uint256 _advanceReleaseDate,
        uint256 _vestingStartDate,
        address _crowdfundingVault
    ) private {
        uint256 _totalAmount = 0;
        for (uint256 r = 0; r < _rewardOwners.length; r++) {
            address _rewardOwner = _rewardOwners[r];
            uint256 _advanceAmount = _advanceAmountPerAddress[r];
            uint256 _investorTotalAmount = _advanceAmount;
            if (investors[_rewardOwner].totalAmount > 0) {
                revert InvestorAlreadyAdded(_rewardOwner);
            }
            if (_advanceAmount > 0) {
                tokenRewards[_rewardOwner].push(
                    TokenReward({
                        amount: _advanceAmount,
                        releaseDate: _advanceReleaseDate,
                        isClaimed: false,
                        isActive: true
                    })
                );
            }

            for (uint256 i = 0; i < _vestingCount; i++) {
                uint256 _vestingAmount;
                if (i == _vestingCount - 1) {
                    _vestingAmount = (_advanceAmount + _totalOfVestings[r]) - _investorTotalAmount;
                } else {
                    _vestingAmount = _totalOfVestings[r] / _vestingCount;
                }
                tokenRewards[_rewardOwner].push(
                    TokenReward({
                        amount: _vestingAmount,
                        releaseDate: _vestingStartDate + (30 days * i),
                        isClaimed: false,
                        isActive: true
                    })
                );
                _investorTotalAmount += _vestingAmount;
            }
            _totalAmount += _investorTotalAmount;

            investors[_rewardOwner] = Investor({
                totalAmount: _investorTotalAmount,
                vestingCount: _advanceAmount > 0 ? (_vestingCount + 1) : _vestingCount,
                currentVestingIndex: 0,
                blacklistDate: 0
            });
            investorList.push(_rewardOwner);
        }

        totalRewardAmount += _totalAmount;
        if (freeBalance < _totalAmount) {
            soulsToken.safeTransferFrom(_crowdfundingVault, address(this), _totalAmount - freeBalance);
            freeBalance = 0;
        } else {
            //No need to transfer additional tokens
            freeBalance -= _totalAmount;
        }
    }

    //Managers Function
    function deactivateInvestorVesting(
        address _rewardOwner,
        uint8[] calldata _vestingIndexes,
        string calldata _description
    ) external onlyManager {
        if (_rewardOwner == address(0)) revert ZeroAddress();
        if (tokenRewards[_rewardOwner].length == 0) revert RewardOwnerNotFound();

        string memory _vestingsToDeactivate;
        for (uint256 i = 0; i < _vestingIndexes.length; i++) {
            if (_vestingIndexes[i] >= investors[_rewardOwner].vestingCount) revert InvalidVestingIndex();
            if (tokenRewards[_rewardOwner][_vestingIndexes[i]].isClaimed) revert AlreadyClaimed();
            if (!tokenRewards[_rewardOwner][_vestingIndexes[i]].isActive) revert AlreadyDeactive();

            _vestingsToDeactivate = string.concat(_vestingsToDeactivate, Strings.toString(_vestingIndexes[i]));
            if (i < _vestingIndexes.length - 1) {
                _vestingsToDeactivate = string.concat(_vestingsToDeactivate, ", ");
            }
        }

        string memory _title = string.concat(
            "Deactivate Investor (",
            Strings.toHexString(_rewardOwner),
            ") Vesting (",
            _vestingsToDeactivate,
            ")"
        );
        bytes memory _encodedValues = abi.encode(_rewardOwner, _vestingIndexes, _description);

        managers.approveTopic(_title, _encodedValues);
        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            uint256 _totalAmountToDeactivate;
            for (uint256 i = 0; i < _vestingIndexes.length; i++) {
                tokenRewards[_rewardOwner][_vestingIndexes[i]].isActive = false;
                _totalAmountToDeactivate += tokenRewards[_rewardOwner][_vestingIndexes[i]].amount;
            }
            freeBalance += _totalAmountToDeactivate;
            // soulsToken.safeTransfer(crowdfundingVault, _totalAmountToDeactivate);
            totalRewardAmount -= _totalAmountToDeactivate;

            managers.deleteTopic(_title);
        }
        emit DeactivateVesting(msg.sender, _rewardOwner, _vestingIndexes, _description, _isApproved);
    }

    //Managers Function
    function activateInvestorVesting(
        address _rewardOwner,
        uint8[] calldata _vestingIndexes,
        address _tokenSource,
        string calldata _description
    ) external onlyManager {
        if (_rewardOwner == address(0)) {
            revert ZeroAddress();
        }
        if (tokenRewards[_rewardOwner].length == 0) {
            revert RewardOwnerNotFound();
        }

        string memory _vestingsToActivate;
        for (uint256 i = 0; i < _vestingIndexes.length; i++) {
            if (_vestingIndexes[i] >= investors[_rewardOwner].vestingCount) {
                revert InvalidVestingIndex();
            }
            if (tokenRewards[_rewardOwner][_vestingIndexes[i]].isActive) {
                revert AlreadyActive();
            }
            _vestingsToActivate = string.concat(_vestingsToActivate, Strings.toString(_vestingIndexes[i]));
            if (i < _vestingIndexes.length - 1) {
                _vestingsToActivate = string.concat(_vestingsToActivate, ", ");
            }
        }

        string memory _title = string.concat(
            "Activate Investor (",
            Strings.toHexString(_rewardOwner),
            ") Vesting (",
            _vestingsToActivate,
            ")"
        );

        bytes memory _encodedValues = abi.encode(_rewardOwner, _vestingIndexes, _description);

        managers.approveTopic(_title, _encodedValues);
        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            uint256 _totalAmountToActivate;
            for (uint256 i = 0; i < _vestingIndexes.length; i++) {
                tokenRewards[_rewardOwner][_vestingIndexes[i]].isActive = true;
                _totalAmountToActivate += tokenRewards[_rewardOwner][_vestingIndexes[i]].amount;
            }
            if (freeBalance >= _totalAmountToActivate) {
                freeBalance -= _totalAmountToActivate;
            } else {
                soulsToken.safeTransferFrom(_tokenSource, address(this), _totalAmountToActivate - freeBalance);
            }

            totalRewardAmount += _totalAmountToActivate;

            managers.deleteTopic(_title);
        }
        emit ActivateVesting(msg.sender, _rewardOwner, _vestingIndexes, _description, _isApproved);
    }

    //Managers Function
    function addToBlacklist(address _rewardOwner, string calldata _description) external onlyManager {
        if (_rewardOwner == address(0)) revert ZeroAddress();
        if (tokenRewards[_rewardOwner].length == 0) revert RewardOwnerNotFound();
        if (isInBlacklist(_rewardOwner, block.timestamp)) revert AlreadyBlacklisted();

        string memory _title = string.concat("Add To Blacklist (", Strings.toHexString(_rewardOwner), ")");

        bytes memory _encodedValues = abi.encode(_rewardOwner, _description);

        managers.approveTopic(_title, _encodedValues);
        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            uint256 _remainingAmount = 0;
            uint256 _totalRewardAmount = totalRewardAmount;
            for (uint256 i = 0; i < tokenRewards[_rewardOwner].length; i++) {
                if (tokenRewards[_rewardOwner][i].releaseDate > block.timestamp) {
                    _remainingAmount += tokenRewards[_rewardOwner][i].amount;
                    _totalRewardAmount -= tokenRewards[_rewardOwner][i].amount;
                }
            }
            totalRewardAmount = _totalRewardAmount;
            freeBalance += _remainingAmount;
            investors[_rewardOwner].blacklistDate = block.timestamp;
            managers.deleteTopic(_title);
        }
        emit AddToBlacklist(msg.sender, _rewardOwner, _description, _isApproved);
    }

    //Managers Function
    function removeFromBlacklist(
        address _rewardOwner,
        address _tokenSource,
        string calldata _description
    ) external onlyManager {
        if (_rewardOwner == address(0)) revert ZeroAddress();
        if (!isInBlacklist(_rewardOwner, block.timestamp)) revert NotBlacklisted();

        string memory _title = string.concat("Remove From Blacklist (", Strings.toHexString(_rewardOwner), ")");
        bytes memory _encodedValues = abi.encode(_rewardOwner, _description);
        managers.approveTopic(_title, _encodedValues);
        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            uint256 _requiredAmount;
            uint256 _totalRewardAmount = totalRewardAmount;
            for (uint256 i = 0; i < tokenRewards[_rewardOwner].length; i++) {
                if (tokenRewards[_rewardOwner][i].releaseDate > investors[_rewardOwner].blacklistDate) {
                    _requiredAmount += tokenRewards[_rewardOwner][i].amount;
                    _totalRewardAmount += tokenRewards[_rewardOwner][i].amount;
                }
            }
            totalRewardAmount = _totalRewardAmount;
            if (freeBalance >= _requiredAmount) {
                freeBalance -= _requiredAmount;
            } else {
                soulsToken.safeTransferFrom(_tokenSource, address(this), _requiredAmount - freeBalance);
            }
            investors[_rewardOwner].blacklistDate = 0;
            managers.deleteTopic(_title);
        }
        emit RemoveFromBlacklist(msg.sender, _rewardOwner, _description, _isApproved);
    }

    function claimTokens(
        uint8 _vestingIndex
    ) public ifNotBlacklisted(tokenRewards[msg.sender][_vestingIndex].releaseDate) {
        if (_vestingIndex != investors[msg.sender].currentVestingIndex) {
            revert VestingIndexShouldBeEqualToCurrentVestingIndex();
        }
        if (tokenRewards[msg.sender][_vestingIndex].releaseDate > block.timestamp) {
            revert EarlyRequest();
        }

        if (tokenRewards[msg.sender][_vestingIndex].isClaimed) {
            revert AlreadyClaimed();
        }
        if (!tokenRewards[msg.sender][_vestingIndex].isActive) {
            revert RewardIsDeactivated();
        }
        tokenRewards[msg.sender][_vestingIndex].isClaimed = true;
        investors[msg.sender].currentVestingIndex++;
        totalClaimedAmount += tokenRewards[msg.sender][_vestingIndex].amount;
        soulsToken.safeTransfer(msg.sender, tokenRewards[msg.sender][_vestingIndex].amount);
        emit Claim(msg.sender, _vestingIndex, tokenRewards[msg.sender][_vestingIndex].amount);
    }

    //Read Functions
    function getAllVestingInfoForAccount(address _rewardOwner) public view returns (TokenReward[] memory) {
        return tokenRewards[_rewardOwner];
    }

    function getVestingInfoForAccount(
        address _rewardOwner,
        uint8 _vestingIndex
    ) public view returns (TokenReward memory) {
        return tokenRewards[_rewardOwner][_vestingIndex];
    }

    function getInvestorList() public view returns (address[] memory) {
        return investorList;
    }

    function isInBlacklist(address _address, uint256 _time) public view returns (bool) {
        return investors[_address].blacklistDate != 0 && investors[_address].blacklistDate < _time;
    }
}
