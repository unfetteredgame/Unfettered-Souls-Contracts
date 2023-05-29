// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/interfaces/IERC1155.sol";
struct GameItem {
    uint256 id;
    string name;
    string uri;
    uint256 totalSupply;
    uint256 maxSupply;
    uint256 mintCost;
    bool inUse;
}

interface IERC1155GameItem is IERC1155 {
    function itemCount() external view returns (uint256);

    function createNewItem(string calldata _name, string calldata _uri, uint256 _maxSupply, uint256 _mintCost) external;

    function removeItem(uint256 _tokenId) external;

    function getItemList() external view returns (GameItem[] memory _returnData);

    function setAuthorizedAddress(address _newAddress) external;

    function setTreasury(address payable _newAddress) external;

    function transferToGame(address _from, uint256[] calldata _tokenIds, uint256[] calldata _amounts) external;

    function transferToPlayer(address _to, uint256[] calldata _tokenIds, uint256[] calldata _amounts) external;

    function claimForPlayer(address _player, uint256 _tokenId, uint256 _amount) external;

    function withdraw() external payable;
}
