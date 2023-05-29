// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "./Vault.sol";
import "../interfaces/IPancakeFactory.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IAirdrop.sol";

contract AirdropVault is Vault {
    using ERC165Checker for address;

    //Storage Variables
    address public airdropContractAddress;

    //Custom Errors
    error Use_depositToAirdropContract_function();
    error InvalidAirdropContract();

    //Events
    event DepositToAirdropContract(address airdropContractAddress, uint256 amount, bool isApproved);

    constructor(
        address _mainVaultAddress,
        address _soulsTokenAddress,
        address _managersAddress
    ) Vault("Airdrop Vault", _mainVaultAddress, _soulsTokenAddress, _managersAddress) {}

    //Write Functions
    function withdrawTokens(address[] calldata, uint256[] calldata) external view override onlyManager {
        revert Use_depositToAirdropContract_function();
    }

    //Managers Function
    function depositToAirdropContract(address _airdropContractAddress, uint256 _amount) external onlyManager {
        if (!_airdropContractAddress.supportsInterface(type(IAirdrop).interfaceId)) {
            revert InvalidAirdropContract();
        }

        if (_amount == 0) {
            revert ZeroAmount();
        }

        address[] memory _receiverAddresses = new address[](1);
        uint256[] memory _amounts = new uint256[](1);

        _receiverAddresses[0] = _airdropContractAddress;
        _amounts[0] = _amount;

        bool _isApproved = _withdrawTokens(_receiverAddresses, _amounts);
        if (_isApproved) {
            airdropContractAddress = _airdropContractAddress;
        }

        emit DepositToAirdropContract(_airdropContractAddress, _amount, _isApproved);
    }
}
