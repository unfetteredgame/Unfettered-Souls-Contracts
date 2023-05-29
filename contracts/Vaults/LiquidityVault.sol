// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "./Vault.sol";
import "../interfaces/IERC20Extended.sol";
import "../interfaces/IPancakeFactory.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/IPancakePair.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LiquidityVault is Vault {
    using SafeERC20 for IERC20;

    //Storage Variables
    uint256 public constant liquidityShare = 60_000_000 ether;
    uint256 public constant tokenAmountForInitialLiquidityOnDEX = 3_000_000 ether;
    uint256 public constant marketMakerShare = 50_000_000 ether;
    uint256 public immutable initialPriceForDEX;
    uint256 public balanceAddedLiquidityOnDex;
    uint256 public remainingTokensUnlockTime;
    uint256 public immutable marketMakerShareWithdrawDeadline;
    uint256 public marketMakerShareWithdrawnAmount;

    address public DEXPairAddress;
    address immutable stableTokenAddress;
    address immutable factoryAddress;
    address immutable routerAddress;

    //Custom Errors
    error StableBalanceIsNotEnoughOnLiquidityVault();
    error InsufficientTokenBalanceInLiquidityVault();
    error Use_withdrawRemainingTokens_function();
    error ReceiversAndAmountsMustBeSameLength();
    error RemainingTokensAreStillLocked();
    error AmountExceedsTheLimits();
    error NotEnoughSOULSToken();
    error IdenticalAddresses();
    error InvalidAmount();
    error LateRequest();

    //Events
    event InitialLiquidityAdded(
        address soulsTokenAddress,
        address stableTokenAddress,
        uint256 tokenAmountForInitialLiquidityOnDEX,
        uint256 stableAmountForLiquidty
    );
    event AddLiquidityOnDEX(
        address soulsTokenAddress,
        address stableTokenAddress,
        uint256 tokenAmountToAdd,
        uint256 stableAmountToAdd,
        bool isApproved
    );
    event WithdrawMarketMakerShare(address receiver, uint256 amount, bool isApproved);
    event WithdrawRemainingTokens(address[] receivers, uint256[] amounts, bool isApproved);

    constructor(
        address _mainVaultAddress,
        address _soulsTokenAddress,
        address _managersAddress,
        address _dexRouterAddress,
        address _dexFactoryAddress,
        address _stableTokenAddress
    ) Vault("Liquidity Vault", _mainVaultAddress, _soulsTokenAddress, _managersAddress) {
        if (_dexRouterAddress == address(0) || _dexFactoryAddress == address(0) || _stableTokenAddress == address(0)) {
            revert ZeroAddress();
        }
        routerAddress = _dexRouterAddress;
        factoryAddress = _dexFactoryAddress;
        stableTokenAddress = _stableTokenAddress;
        initialPriceForDEX = (9 * (10 ** IERC20Extended(_stableTokenAddress).decimals())) / 1000;
        marketMakerShareWithdrawDeadline = block.timestamp + 5 days;
    }

    //Write Functions

    //Managers Function
    function addLiquidityOnDEX(uint256 _tokenAmountToAdd) external onlyManager {
        if (_tokenAmountToAdd == 0) {
            revert ZeroAmount();
        }

        if (_tokenAmountToAdd > IERC20(soulsTokenAddress).balanceOf(address(this))) {
            revert NotEnoughSOULSToken();
        }

        IPancakeRouter02 _router = IPancakeRouter02(routerAddress);
        uint256 _stableAmountToAdd = getRequiredStableAmountForLiquidity(_tokenAmountToAdd); // _router.quote(_tokenAmountToAdd, soulsReserve, stableReserve);
        IERC20 stableToken = IERC20(stableTokenAddress);

        if (_stableAmountToAdd > stableToken.balanceOf(address(this))) {
            revert StableBalanceIsNotEnoughOnLiquidityVault();
        }

        string memory _title = "Add Liquidity On DEX";
        bytes memory _encodedValues = abi.encode(_tokenAmountToAdd);
        managers.approveTopic(_title, _encodedValues);
        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            balanceAddedLiquidityOnDex += _tokenAmountToAdd;
            if (tokenVestings[0].amount >= _tokenAmountToAdd) {
                tokenVestings[0].amount -= _tokenAmountToAdd;
            } else {
                tokenVestings[0].amount = 0;
            }
            IERC20(soulsTokenAddress).safeApprove(address(routerAddress), _tokenAmountToAdd);
            stableToken.safeApprove(address(routerAddress), _stableAmountToAdd);
            _router.addLiquidity(
                soulsTokenAddress,
                stableTokenAddress,
                _tokenAmountToAdd,
                _stableAmountToAdd,
                _tokenAmountToAdd,
                0,
                mainVaultAddress,
                block.timestamp + 1 hours
            );

            if (stableToken.balanceOf(address(this)) > 0) {
                stableToken.safeTransfer(msg.sender, stableToken.balanceOf(address(this)));
            }
            managers.deleteTopic(_title);
        }

        emit AddLiquidityOnDEX(soulsTokenAddress, stableTokenAddress, _tokenAmountToAdd, 0, _isApproved);
    }

    //Managers Function
    function withdrawMarketMakerShare(address _receiver, uint256 _amount) external onlyManager {
        if (block.timestamp > marketMakerShareWithdrawDeadline) {
            revert LateRequest();
        }

        if (marketMakerShareWithdrawnAmount + _amount > marketMakerShare) {
            revert AmountExceedsTheLimits();
        }
        string memory _title = "Withdraw Market Maker Share";
        bytes memory _encodedValues = abi.encode(_receiver, _amount);
        managers.approveTopic(_title, _encodedValues);

        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            marketMakerShareWithdrawnAmount += _amount;
            if (tokenVestings[0].amount >= _amount) {
                tokenVestings[0].amount -= _amount;
            } else {
                tokenVestings[0].amount = 0;
            }
            IERC20 soulsToken = IERC20(soulsTokenAddress);
            soulsToken.safeTransfer(_receiver, _amount);

            managers.deleteTopic(_title);
        }

        emit WithdrawMarketMakerShare(_receiver, _amount, _isApproved);
    }

    function createVestings(
        uint256 _totalAmount,
        uint256 _initialRelease,
        uint256 _initialReleaseDate,
        uint256 _lockDurationInDays,
        uint256 _countOfVestings,
        uint256 _releaseFrequencyInDays
    ) public override onlyOnce onlyMainVault {
        if (_totalAmount != liquidityShare) {
            revert InvalidAmount();
        }
        super.createVestings(
            _totalAmount,
            _initialRelease,
            _initialReleaseDate,
            _lockDurationInDays,
            _countOfVestings,
            _releaseFrequencyInDays
        );
        IERC20(soulsTokenAddress).safeTransferFrom(msg.sender, address(this), liquidityShare);
        remainingTokensUnlockTime = _initialReleaseDate + 365 days;
        _createLiquidityOnDex();
    }

    function withdrawTokens(address[] calldata, uint256[] calldata) external view override onlyManager {
        revert Use_withdrawRemainingTokens_function();
    }

    //Managers Function
    function withdrawRemainingTokens(address[] calldata _receivers, uint256[] calldata _amounts) external onlyManager {
        if (block.timestamp <= remainingTokensUnlockTime) {
            revert RemainingTokensAreStillLocked();
        }

        if (_receivers.length != _amounts.length) {
            revert ReceiversAndAmountsMustBeSameLength();
        }
        uint256 _totalAmount;
        for (uint i = 0; i < _amounts.length; i++) {
            _totalAmount += _amounts[i];
        }

        if (_totalAmount > IERC20(soulsTokenAddress).balanceOf(address(this))) {
            revert InsufficientTokenBalanceInLiquidityVault();
        }

        string memory _title = "Withdraw remaining tokens from Liquidity Vault";
        bytes memory _encodedValues = abi.encode(_receivers, _amounts);
        managers.approveTopic(_title, _encodedValues);
        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            for (uint i = 0; i < _amounts.length; i++) {
                IERC20(soulsTokenAddress).safeTransfer(_receivers[i], _amounts[i]);
            }
            managers.deleteTopic(_title);
        }
        emit WithdrawRemainingTokens(_receivers, _amounts, _isApproved);
    }

    function _createLiquidityOnDex() private {
        uint256 _stableAmountForLiquidty = stableAmountForInitialLiquidity();
        balanceAddedLiquidityOnDex += tokenAmountForInitialLiquidityOnDEX;
        IERC20(soulsTokenAddress).safeApprove(address(routerAddress), tokenAmountForInitialLiquidityOnDEX);
        IERC20(stableTokenAddress).safeApprove(address(routerAddress), _stableAmountForLiquidty);
        IPancakeRouter02 _router = IPancakeRouter02(routerAddress);

        _router.addLiquidity(
            soulsTokenAddress,
            stableTokenAddress,
            tokenAmountForInitialLiquidityOnDEX,
            _stableAmountForLiquidty,
            tokenAmountForInitialLiquidityOnDEX,
            _stableAmountForLiquidty,
            mainVaultAddress,
            block.timestamp + 5 minutes
        );
        IPancakeFactory _factory = IPancakeFactory(factoryAddress);
        DEXPairAddress = _factory.getPair(soulsTokenAddress, stableTokenAddress);
        tokenVestings[0].amount -= tokenAmountForInitialLiquidityOnDEX;

        emit InitialLiquidityAdded(
            soulsTokenAddress,
            stableTokenAddress,
            tokenAmountForInitialLiquidityOnDEX,
            _stableAmountForLiquidty
        );
    }

    // Read Functions
    function stableAmountForInitialLiquidity() public view returns (uint256 _stableAmount) {
        _stableAmount = ((tokenAmountForInitialLiquidityOnDEX / 1 ether) * initialPriceForDEX);
    }

    function getSoulsBalance() public view returns (uint256 _soulsBalance) {
        _soulsBalance = IERC20(soulsTokenAddress).balanceOf(address(this));
    }

    function getRequiredStableAmountForLiquidity(
        uint256 _tokenAmountToAdd
    ) public view returns (uint256 _stableAmountForLiquidty) {
        (uint256 stableReserve, uint256 soulsReserve) = _getReserves(stableTokenAddress, soulsTokenAddress);
        IPancakeRouter02 _router = IPancakeRouter02(routerAddress);
        _stableAmountForLiquidty = _router.quote(_tokenAmountToAdd, soulsReserve, stableReserve);
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        if (tokenA == tokenB) {
            revert IdenticalAddresses();
        }

        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        if (token0 == address(0)) {
            revert ZeroAddress();
        }
    }

    function _getReserves(address tokenA, address tokenB) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, ) = _sortTokens(tokenA, tokenB);
        IPancakeFactory _factory = IPancakeFactory(factoryAddress);
        address _pairAddress = _factory.getPair(stableTokenAddress, soulsTokenAddress);
        IPancakePair pair = IPancakePair(_pairAddress);

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }
}
