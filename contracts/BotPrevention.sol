// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "./interfaces/IManagers.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BotPrevention is Ownable {
    //Structs
    struct BotProtectionParams {
        uint256 activateIfBalanceExeeds;
        uint256 maxSellAmount;
        uint256 durationBetweenSells;
    }

    //Storage Variables
    IManagers private managers;
    BotProtectionParams public botPreventionParams;

    address public tokenAddress;
    address public dexPairAddress;

    uint256 public tradingStartTimeOnDEX;
    uint256 public botPreventionDuration = 15 seconds;
    uint256 public currentSession;

    bool public tradingEnabled = true;

    mapping(address => uint256) public walletCanSellAfter;
    mapping(uint256 => mapping(address => uint256)) private boughtAmountDuringBotProtection;

    //Custom Errors
    error BotPreventionAmountLock();
    error BotPreventionTimeLock();
    error SetTokenAddressFirst();
    error MustBeInTheFuture();
    error TradingIsDisabled();
    error TradingNotStarted();
    error AlreadyDisabled();
    error IncorrectToken();
    error AlreadyEnabled();
    error NotAuthorized();
    error ZeroAddress();
    error AlreadySet();

    //Events
    event ResetBotPreventionData(uint256 currentSession);
    event EnableTrading(address manager, bool isApproved);
    event DisableTrading(address manager, bool isApproved);

    constructor(uint256 _tradingStartTime) {
        botPreventionParams = BotProtectionParams({
            activateIfBalanceExeeds: 10000 ether,
            maxSellAmount: 1000 ether,
            durationBetweenSells: 10 minutes
        });
        tradingStartTimeOnDEX = _tradingStartTime;
    }

    //Modifiers
    modifier onlyManager() {
        if (!managers.isManager(msg.sender)) {
            revert NotAuthorized();
        }
        _;
    }

    modifier onlyTokenContract() {
        if (tokenAddress != msg.sender) {
            revert IncorrectToken();
        }
        _;
    }

    //Write Functions
    function setBotPreventionParams(
        uint256 _activationLimit,
        uint256 _maxSellAmount,
        uint256 _durationBetweenSellsInMinutes
    ) external onlyOwner {
        botPreventionParams = BotProtectionParams({
            activateIfBalanceExeeds: _activationLimit,
            maxSellAmount: _maxSellAmount,
            durationBetweenSells: _durationBetweenSellsInMinutes
        });
    }

    //Managers function
    function enableTrading(uint256 _tradingStartTime, uint256 _botPreventionDurationInMinutes) external onlyManager {
        if (tokenAddress == address(0)) {
            revert SetTokenAddressFirst();
        }
        if (tradingEnabled) {
            revert AlreadyEnabled();
        }
        if (_tradingStartTime < block.timestamp) {
            revert MustBeInTheFuture();
        }

        string memory _title = "Enable/Disable Trading";
        bytes memory _encodedValues = abi.encode(true, _tradingStartTime, _botPreventionDurationInMinutes);
        managers.approveTopic(_title, _encodedValues);

        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            tradingEnabled = true;
            tradingStartTimeOnDEX = _tradingStartTime;
            botPreventionDuration = _botPreventionDurationInMinutes * 1 minutes;
            managers.deleteTopic(_title);
        }
        emit EnableTrading(msg.sender, _isApproved);
    }

    //Managers function
    function disableTrading() external onlyManager {
        if (!tradingEnabled) {
            revert AlreadyDisabled();
        }
        string memory _title = "Enable/Disable Trading";
        bytes memory _encodedValues = abi.encode(false, 0, 0);
        managers.approveTopic(_title, _encodedValues);

        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            tradingEnabled = false;
            managers.deleteTopic(_title);
        }
        emit DisableTrading(msg.sender, _isApproved);
    }

    function resetBotPreventionData() external onlyTokenContract {
        tradingStartTimeOnDEX = block.timestamp;
        currentSession++;

        emit ResetBotPreventionData(currentSession);
    }

    function setTokenAddress(address _tokenAddress) external onlyOwner {
        if (_tokenAddress == address(0)) {
            revert ZeroAddress();
        }
        if (tokenAddress != address(0)) {
            revert AlreadySet();
        }
        tokenAddress = _tokenAddress;
    }

    function setManagersAddress(address _address) external onlyOwner {
        if (_address == address(0)) {
            revert ZeroAddress();
        }
        managers = IManagers(_address);
    }

    function setDexPairAddress(address _pairAddress) external onlyOwner {
        if (dexPairAddress != address(0)) {
            revert AlreadySet();
        }
        if (_pairAddress == address(0)) {
            revert ZeroAddress();
        }
        dexPairAddress = _pairAddress;
        // tradingEnabled = false;
    }

    function beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) external view onlyTokenContract returns (bool) {
        if (((dexPairAddress != address(0) && (from == dexPairAddress)) || to == dexPairAddress)) {
            //Trade transaction
            if (!tradingEnabled) {
                revert TradingIsDisabled();
            }
            if (block.timestamp < tradingStartTimeOnDEX) {
                revert TradingNotStarted();
            }
            if (block.timestamp < tradingStartTimeOnDEX + botPreventionDuration) {
                //While bot protection is active
                if (to == dexPairAddress) {
                    //Selling Souls
                    if (block.timestamp < walletCanSellAfter[from]) {
                        revert BotPreventionTimeLock();
                    }
                    if (walletCanSellAfter[from] > 0) {
                        if (amount > botPreventionParams.maxSellAmount) {
                            revert BotPreventionAmountLock();
                        }
                    }
                }
            }
		}
        return true;
    }

    function afterTokenTransfer(address from, address to, uint256 amount) external onlyTokenContract returns (bool) {
        if (dexPairAddress != address(0) && block.timestamp < tradingStartTimeOnDEX + botPreventionDuration) {
            if (from == dexPairAddress) {
                //Buying Tokens
                if (
                    block.timestamp > tradingStartTimeOnDEX &&
                    block.timestamp < tradingStartTimeOnDEX + botPreventionDuration
                ) {
                    boughtAmountDuringBotProtection[currentSession][to] += amount;
                }
                if (boughtAmountDuringBotProtection[currentSession][to] > botPreventionParams.activateIfBalanceExeeds) {
                    walletCanSellAfter[to] = block.timestamp + botPreventionParams.durationBetweenSells;
                }
            } else if (to == dexPairAddress) {
                //Selling Tokens
                if (
                    block.timestamp > tradingStartTimeOnDEX &&
                    block.timestamp < tradingStartTimeOnDEX + botPreventionDuration
                ) {
                    if (boughtAmountDuringBotProtection[currentSession][from] >= amount) {
                        boughtAmountDuringBotProtection[currentSession][from] -= amount;
                    }
                }
                if (walletCanSellAfter[from] > 0) {
                    walletCanSellAfter[from] = block.timestamp + botPreventionParams.durationBetweenSells;
                }
            } else {
                //Standard transfer
                if (IERC20(tokenAddress).balanceOf(to) > botPreventionParams.activateIfBalanceExeeds) {
                    walletCanSellAfter[to] = block.timestamp + botPreventionParams.durationBetweenSells;
                }
            }
        }
        return true;
    }
}
