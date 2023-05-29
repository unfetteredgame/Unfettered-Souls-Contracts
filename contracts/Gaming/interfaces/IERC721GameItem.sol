// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;
import "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";

interface IERC721GameItem is IERC721Enumerable {

    function setAuthorizedAddress(address _newAddress) external;

    function setTreasury(address payable _newAddress) external;

    function setTokenUri(uint256 _tokenId, string calldata _uri) external;

    function setMintCost(uint256 _newCost) external;

    function mint() external payable;

    function claimForPlayer(address _player) external;

    function walletOfOwner(address _owner) external view returns (uint256[] memory);

    function withdraw() external payable;
}
