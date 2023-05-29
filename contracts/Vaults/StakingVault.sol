// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "./Vault.sol";
import "../interfaces/IPancakeFactory.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IStaking.sol";

contract StakingVault is Vault {
    using ERC165Checker for address;

    //Storage Variables
    address public stakingContractAddress;

    //Custom Errors
    error Use_depositToStakingContract();
    error InvalidStakingContract();

    //Events
    event DepositToStakingContract(address stakingContractAddress, uint256 amount, bool isApproved);

    constructor(
        address _mainVaultAddress,
        address _soulsTokenAddress,
        address _managersAddress
    ) Vault("Staking Vault", _mainVaultAddress, _soulsTokenAddress, _managersAddress) {}

    //Write Functions
    function withdrawTokens(address[] calldata, uint256[] calldata) external view override onlyManager {
        revert Use_depositToStakingContract();
    }

    //Managers Function
    function depositToStakingContract(address _stakingContractAddress, uint256 _amount) external onlyManager {
        if (!_stakingContractAddress.supportsInterface(type(IStaking).interfaceId)) {
            revert InvalidStakingContract();
        }

        if (_amount == 0) {
            revert ZeroAmount();
        }

        address[] memory _receiverAddresses = new address[](1);
        uint256[] memory _amounts = new uint256[](1);

        _receiverAddresses[0] = _stakingContractAddress;
        _amounts[0] = _amount;

        bool _isApproved = _withdrawTokens(_receiverAddresses, _amounts);
        if (_isApproved) {
            stakingContractAddress = _stakingContractAddress;
        }

        emit DepositToStakingContract(_stakingContractAddress, _amount, _isApproved);
    }
}
