// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IPlayToEarnVault.sol";
import "./interfaces/ILiquidityVault.sol";
import "./interfaces/ICrowdfundingVault.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/ICrowdfunding.sol";
import "./interfaces/IBotPrevention.sol";
import "./interfaces/IManagers.sol";
import "./SoulsToken.sol";

contract MainVault is Ownable {
    using SafeERC20 for IERC20;

    //Storage Variables
    SoulsToken public immutable soulsToken;
    IManagers public immutable managers;

    uint256 public liquidityTokensUnlockTime;

    //Tokenomi
    uint256 public constant crowdfundingShare = 613_820_200 ether;
    uint256 public constant playToEarnShare = 900_000_000 ether;
    uint256 public constant marketingShare = 300_000_000 ether;
    uint256 public constant liquidityShare = 60_000_000 ether;
    uint256 public constant treasuryShare = 226_179_800 ether;
    uint256 public constant stakingShare = 300_000_000 ether;
    uint256 public constant advisorShare = 150_000_000 ether;
    uint256 public constant airdropShare = 150_000_000 ether;
    uint256 public constant teamShare = 300_000_000 ether;

    address public crowdfundingVaultAddress;
    address public playToEarnVaultAddress;
    address public marketingVaultAddress;
    address public liquidityVaultAddress;
    address public treasuryVaultAddress;
    address public advisorVaultAddress;
    address public stakingVaultAddress;
    address public airdropVaultAddress;
    address public teamVaultAddress;
    address public dexPairAddress;

    enum VaultEnumerator {
        MARKETING,
        ADVISOR,
        TEAM,
        TREASURY,
        AIRDROP,
        STAKING
    }

    //Custom Errors
    error ManagerAddressCannotBeAddedToTrustedSources();
    error GameStartDayCanBeMaximum60DaysBefore();
    error LiquidityVaultNotInitialized();
    error GameStartTimeMustBeInThePast();
    error InvalidCrowdfundingContract();
    error DateMustBeInTheFuture();
    error AlreadyInitialized();
    error InvalidVaultIndex();
    error ZeroBalanceOfLP();
    error EmptyNameString();
    error NotAuthorized();
    error ZeroAddress();
    error ZeroAmount();
    error StillLocked();

    //Events
    event SetCrowdfundingContracts(
        address manager,
        address seedSaleContract,
        address strategicSaleContract,
        address privateSaleContract,
        address publicSaleContract,
        bool isApproved
    );
    event AddAddressToTrustedSources(address manager, address addr, string name, bool isApproved);

    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        IManagers _managers,
        address _botPreventionAddress
    ) {
        managers = _managers;
        soulsToken = new SoulsToken(_tokenName, _tokenSymbol, address(managers), _botPreventionAddress);
        soulsToken.transferOwnership(msg.sender);
    }

    //Modifiers
    modifier onlyManager() {
        if (!managers.isManager(msg.sender)) {
            revert NotAuthorized();
        }
        _;
    }

    // //Write Functions
    // Managers Function
    function initPlayToEarnVault(address _playToEarnVaultAddress, uint256 _gameStartTime) external onlyManager {
        if (playToEarnVaultAddress != address(0)) {
            revert AlreadyInitialized();
        }
        if (_playToEarnVaultAddress == address(0)) {
            revert ZeroAddress();
        }
        if (_gameStartTime >= block.timestamp) {
            revert GameStartTimeMustBeInThePast();
        }

        string memory _title = "Init Play To Earn Vault";
        bytes memory _encodedValues = abi.encode(_playToEarnVaultAddress, _gameStartTime);
        managers.approveTopic(_title, _encodedValues);

        if (managers.isApproved(_title, _encodedValues)) {
            playToEarnVaultAddress = _playToEarnVaultAddress;
            uint256 daysSinceGameStartTime = (block.timestamp - _gameStartTime) / 1 days;
            if (daysSinceGameStartTime > 60) {
                revert GameStartDayCanBeMaximum60DaysBefore();
            }

            IPlayToEarnVault _playToEarnVault = IPlayToEarnVault(playToEarnVaultAddress);
            soulsToken.approve(playToEarnVaultAddress, playToEarnShare);

            _playToEarnVault.createVestings(playToEarnShare, 0, 0, 86, _gameStartTime + 60 days, 30);

            managers.addAddressToTrustedSources(playToEarnVaultAddress, "PlayToEarn Vault");
            managers.addAddressToTrustedSources(_playToEarnVault.claimContractAddress(), "Withdraw Claim Contract");

            managers.deleteTopic(_title);
        }
    }

    function initLiquidityVault(
        address _liquidityVaultAddress,
        address _stableTokenAddress,
        uint256 _initialReleaseDate
    ) external onlyOwner {
        if (liquidityVaultAddress != address(0)) {
            revert AlreadyInitialized();
        }
        if (_liquidityVaultAddress == address(0)) {
            revert ZeroAddress();
        }
        if (_initialReleaseDate < block.timestamp) {
            revert DateMustBeInTheFuture();
        }
        liquidityVaultAddress = _liquidityVaultAddress;

        ILiquidityVault _liquidityVault = ILiquidityVault(liquidityVaultAddress);
        soulsToken.approve(liquidityVaultAddress, liquidityShare);

        IERC20 stableToken = IERC20(_stableTokenAddress);
        stableToken.safeTransferFrom(
            msg.sender,
            liquidityVaultAddress,
            _liquidityVault.stableAmountForInitialLiquidity()
        );
        _liquidityVault.createVestings(liquidityShare, liquidityShare, _initialReleaseDate, 0, 0, 0);
        dexPairAddress = _liquidityVault.DEXPairAddress();
        liquidityTokensUnlockTime = block.timestamp + 365 days;
        managers.addAddressToTrustedSources(liquidityVaultAddress, "Liquidity Vault");
    }

    function initCrowdfundingVault(
        address _crowdfundingVaultAddress,
        address _seedSaleContract,
        address _strategicSaleContract,
        address _privateSaleContract,
        address _publicSaleContract,
        address _passHolderSaleContract,
        uint256 _initialReleaseDate
    ) external onlyOwner {
        if (crowdfundingVaultAddress != address(0)) {
            revert AlreadyInitialized();
        }

        if (_crowdfundingVaultAddress == address(0)) {
            revert ZeroAddress();
        }
        if (_initialReleaseDate < block.timestamp) {
            revert DateMustBeInTheFuture();
        }
        crowdfundingVaultAddress = _crowdfundingVaultAddress;
        IVault _vault = IVault(_crowdfundingVaultAddress);
        _vault.createVestings(crowdfundingShare, crowdfundingShare, _initialReleaseDate, 0, 0, 0);
        soulsToken.transfer(_crowdfundingVaultAddress, crowdfundingShare);
        managers.addAddressToTrustedSources(_crowdfundingVaultAddress, "Crowdfunding Vault");
        _setCrowdfundingContracts(
            _seedSaleContract,
            _strategicSaleContract,
            _passHolderSaleContract,
            _privateSaleContract,
            _publicSaleContract
        );
    }

    function _setCrowdfundingContracts(
        address _seedSaleContract,
        address _strategicSaleContract,
        address _passHolderSaleContract,
        address _privateSaleContract,
        address _publicSaleContract
    ) private {
        if (
            _seedSaleContract == address(0) ||
            _strategicSaleContract == address(0) ||
            _passHolderSaleContract == address(0) ||
            _privateSaleContract == address(0) ||
            _publicSaleContract == address(0)
        ) {
            revert ZeroAddress();
        }
        ICrowdfundingVault(crowdfundingVaultAddress).setSeedSaleContract(_seedSaleContract);
        ICrowdfundingVault(crowdfundingVaultAddress).setStrategicSaleContract(_strategicSaleContract);
        ICrowdfundingVault(crowdfundingVaultAddress).setPassHolderSaleContract(_passHolderSaleContract);
        ICrowdfundingVault(crowdfundingVaultAddress).setPrivateSaleContract(_privateSaleContract);
        ICrowdfundingVault(crowdfundingVaultAddress).setPublicSaleContract(_publicSaleContract);
    }

    function initVault(
        address _vaultAddress,
        VaultEnumerator _vaultToInit,
        uint256 _initialReleaseDate
    ) external onlyOwner {
        if (_vaultAddress == address(0)) {
            revert ZeroAddress();
        }
        if (_initialReleaseDate < block.timestamp) {
            revert DateMustBeInTheFuture();
        }
        string memory _vaultName;
        uint256 _vaultShare;
        uint256 _initialRelease;
        uint256 _vestingStartDate;
        uint256 _vestingCount;
        uint256 _vestingFrequency;

        if (_vaultToInit == VaultEnumerator.MARKETING) {
            if (marketingVaultAddress != address(0)) {
                revert AlreadyInitialized();
            }

            marketingVaultAddress = _vaultAddress;
            _vaultName = "Marketing Vault";
            _vaultShare = marketingShare;
            _initialRelease = 6_000_000 ether;
            _vestingStartDate = _initialReleaseDate + 90 days;
            _vestingCount = 24;
            _vestingFrequency = 30;
        } else if (_vaultToInit == VaultEnumerator.ADVISOR) {
            if (advisorVaultAddress != address(0)) {
                revert AlreadyInitialized();
            }
            advisorVaultAddress = _vaultAddress;
            _vaultName = "Advisor Vault";
            _vaultShare = advisorShare;
            _initialRelease = 0;
            _vestingStartDate = _initialReleaseDate + 365 days;
            _vestingCount = 24;
            _vestingFrequency = 30;
        } else if (_vaultToInit == VaultEnumerator.TEAM) {
            if (teamVaultAddress != address(0)) {
                revert AlreadyInitialized();
            }
            teamVaultAddress = _vaultAddress;
            _vaultName = "Team Vault";
            _vaultShare = teamShare;
            _initialRelease = 0;
            _vestingStartDate = _initialReleaseDate + 365 days;
            _vestingCount = 24;
            _vestingFrequency = 30;
        } else if (_vaultToInit == VaultEnumerator.TREASURY) {
            if (treasuryVaultAddress != address(0)) {
                revert AlreadyInitialized();
            }
            treasuryVaultAddress = _vaultAddress;
            _vaultName = "Treasury Vault";
            _vaultShare = treasuryShare;
            _initialRelease = 0;
            _vestingStartDate = _initialReleaseDate + 90 days;
            _vestingCount = 48;
            _vestingFrequency = 30;
        } else if (_vaultToInit == VaultEnumerator.AIRDROP) {
            if (airdropVaultAddress != address(0)) {
                revert AlreadyInitialized();
            }
            airdropVaultAddress = _vaultAddress;
            _vaultName = "Airdrop Vault";
            _vaultShare = airdropShare;
            _initialRelease = 0;
            _vestingStartDate = _initialReleaseDate + 240 days;
            _vestingCount = 12;
            _vestingFrequency = 30;
        } else if (_vaultToInit == VaultEnumerator.STAKING) {
            if (stakingVaultAddress != address(0)) {
                revert AlreadyInitialized();
            }
            stakingVaultAddress = _vaultAddress;
            _vaultName = "Staking Vault";
            _vaultShare = stakingShare;
            _initialRelease = 0;
            _vestingStartDate = _initialReleaseDate + 90 days;
            _vestingCount = 6;
            _vestingFrequency = 90;
        } else {
            revert InvalidVaultIndex();
        }

        soulsToken.approve(_vaultAddress, _vaultShare);
        IVault _vault = IVault(_vaultAddress);
        _vault.createVestings(
            _vaultShare,
            _initialRelease,
            _initialReleaseDate,
            _vestingCount,
            _vestingStartDate,
            _vestingFrequency
        );
        managers.addAddressToTrustedSources(_vaultAddress, _vaultName);
    }

    //Managers Function
    function withdrawLPTokens(address _to) external onlyManager {
        if (block.timestamp < liquidityTokensUnlockTime) {
            revert StillLocked();
        }
        if (dexPairAddress == address(0)) {
            revert LiquidityVaultNotInitialized();
        }
        if (_to == address(0)) {
            revert ZeroAddress();
        }
        uint256 _tokenBalance = IERC20(dexPairAddress).balanceOf(address(this));
        if (_tokenBalance == 0) {
            revert ZeroBalanceOfLP();
        }

        string memory _title = "Withdraw LP Tokens";
        bytes memory _encodedValues = abi.encode(_to);
        managers.approveTopic(_title, _encodedValues);

        if (managers.isApproved(_title, _encodedValues)) {
            IERC20(dexPairAddress).safeTransfer(_to, _tokenBalance);
            managers.deleteTopic(_title);
        }
    }

    //Managers Function
    function addAddressToTrustedSources(address _address, string calldata _name) external onlyManager {
        if (managers.isManager(_address)) {
            revert ManagerAddressCannotBeAddedToTrustedSources();
        }
        if (bytes(_name).length == 0) {
            revert EmptyNameString();
        }
        string memory _title = "Add To Trusted Sources";
        bytes memory _encodedValues = abi.encode(_address, _name);
        managers.approveTopic(_title, _encodedValues);

        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            managers.addAddressToTrustedSources(_address, _name);
            managers.deleteTopic(_title);
        }
        emit AddAddressToTrustedSources(msg.sender, _address, _name, _isApproved);
    }
}
