// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "./IVault.sol";

interface ICrowdfundingVault is IVault {
    function setSeedSaleContract(address _seedSaleContractAddress) external;

    function setStrategicSaleContract(address _strategicSaleContractAddress) external;

    function setPassHolderSaleContract(address _passHolderSaleContractAddress) external;

    function setPrivateSaleContract(address _privateSaleContractAddress) external;

    function setPublicSaleContract(address _publicSaleContractAddress) external;
}
