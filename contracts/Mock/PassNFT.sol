// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "hardhat/console.sol";

contract PassNFT is ERC721 {
    uint256 public totalSupply;

    constructor() ERC721("Pass NFT", "UFP") {
	}

    function mint() external {
        _mint(msg.sender, totalSupply);
        totalSupply++;
    }
}
