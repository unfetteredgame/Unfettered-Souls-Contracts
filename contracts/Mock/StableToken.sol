// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title TEST USDT TOKEN
/// @dev To use while adding liquidity on pancakeswap for test purpose.

contract StableToken is ERC20 {
    constructor() ERC20("MyUSDT", "MUSDT") {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
