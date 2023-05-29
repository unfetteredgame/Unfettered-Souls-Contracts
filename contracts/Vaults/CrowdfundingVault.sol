// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Vault.sol";
import "../interfaces/IPancakeFactory.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IAirdrop.sol";

contract CrowdfundingVault is Vault {
    using SafeERC20 for IERC20;

    //Storage Variables
    uint256 seedSaleShare = 210_000_000 ether;
    uint256 strategicSaleShare = 110_000_000 ether;
    uint256 passHolderShare = 23_820_200 ether;
    uint256 privateSaleShare = 210_000_000 ether;
    uint256 publicSaleShare = 60_000_000 ether;

    address public seedSaleContractAddress;
    address public strategicSaleContractAddress;
    address public passHolderSaleContractAddress;
    address public privateSaleContractAddress;
    address public publicSaleContractAddress;

    constructor(
        address _mainVaultAddress,
        address _soulsTokenAddress,
        address _managersAddress
    ) Vault("Crowdfunding Vault", _mainVaultAddress, _soulsTokenAddress, _managersAddress) {}

    //Write Functions
    function setSeedSaleContract(address _seedSaleContractAddress) external onlyMainVault {
        if (_seedSaleContractAddress == address(0)) {
            revert ZeroAddress();
        }
        seedSaleContractAddress = _seedSaleContractAddress;
        IERC20(soulsTokenAddress).safeApprove(_seedSaleContractAddress, seedSaleShare);
    }

    function setStrategicSaleContract(address _strategicSaleContractAddress) external onlyMainVault {
        if (_strategicSaleContractAddress == address(0)) {
            revert ZeroAddress();
        }
        strategicSaleContractAddress = _strategicSaleContractAddress;
        IERC20(soulsTokenAddress).safeApprove(_strategicSaleContractAddress, strategicSaleShare);
    }

    function setPrivateSaleContract(address _privateSaleContractAddress) external onlyMainVault {
        if (_privateSaleContractAddress == address(0)) {
            revert ZeroAddress();
        }
        privateSaleContractAddress = _privateSaleContractAddress;
        IERC20(soulsTokenAddress).safeApprove(_privateSaleContractAddress, privateSaleShare);
    }

    function setPublicSaleContract(address _publicSaleContractAddress) external onlyMainVault {
        if (_publicSaleContractAddress == address(0)) {
            revert ZeroAddress();
        }
        publicSaleContractAddress = _publicSaleContractAddress;
        IERC20(soulsTokenAddress).safeApprove(_publicSaleContractAddress, publicSaleShare);
    }

    function setPassHolderSaleContract(address _passHolderSaleContractAddress) external onlyMainVault {
        if (_passHolderSaleContractAddress == address(0)) {
            revert ZeroAddress();
        }
        passHolderSaleContractAddress = _passHolderSaleContractAddress;
        IERC20(soulsTokenAddress).safeApprove(_passHolderSaleContractAddress, passHolderShare);
    }
}
