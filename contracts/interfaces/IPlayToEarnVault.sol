// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "./IVault.sol";

interface IPlayToEarnVault is IVault {
    function intervalBetweenDistributions() external returns (uint256);

    function distributionOffset() external returns (uint256);

    function claimContractAddress() external returns (address);
}

