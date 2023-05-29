// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {GameItem, IERC1155GameItem} from "./interfaces/IERC1155GameItem.sol";
import "../interfaces/IManagers.sol";



contract ERC1155GameItem is ERC1155, IERC1155GameItem {
    IManagers public managers;

    address inGameItemsInventory;
    address authorizedAddress;
    address payable treasury;

    uint256 public itemCount;

    mapping(uint256 => GameItem) public items;

    error InvalidParameter();
    error ExceedsMaxSupply();
    error NotMintableItem();
    error InvalidTxValue();
    error InvalidTokenId();
    error NotAuthorized();
    error ItemRemoved();
    error ItemInUse();

    constructor(
        IManagers _managers,
        address _authorizedAddress,
        address payable _treasury,
        address _gameInventory
    ) ERC1155("") {
        managers = _managers;
        authorizedAddress = _authorizedAddress;
        treasury = _treasury;
        inGameItemsInventory = _gameInventory;
    }

    modifier onlyManager() {
        if (!managers.isManager(msg.sender)) {
            revert NotAuthorized();
        }
        _;
    }

    modifier onlyAuthorizedAddress() {
        if (msg.sender != authorizedAddress) {
            revert NotAuthorized();
        }
        _;
    }

    modifier onlyInventoryContract() {
        if (msg.sender != inGameItemsInventory) {
            revert NotAuthorized();
        }
        _;
    }

    function setAuthorizedAddress(address _newAddress) external onlyInventoryContract {
        authorizedAddress = _newAddress;
    }

    function setTreasury(address payable _newAddress) external onlyInventoryContract {
        treasury = _newAddress;
    }

    function setTokenUri(uint256 _tokenId, string calldata _uri) external onlyAuthorizedAddress {
        if (bytes(_uri).length == 0) {
            revert InvalidParameter();
        }
        if (_tokenId >= itemCount) {
            revert InvalidTokenId();
        }
        items[_tokenId].uri = _uri;
    }

    function setMintCost(uint256 _tokenId, uint256 _newCost) external onlyManager {
        items[_tokenId].mintCost = _newCost;
    }

    //Tested
    function createNewItem(
        string calldata _name,
        string calldata _uri,
        uint256 _maxSupply,
        uint256 _mintCost
    ) external onlyManager {
        items[itemCount] = GameItem({
            id: itemCount,
            name: _name,
            uri: _uri,
            totalSupply: 0,
            maxSupply: _maxSupply,
            mintCost: _mintCost,
            inUse: true
        });
        itemCount++;
    }

    function removeItem(uint256 _tokenId) external onlyManager {
		if(_tokenId>=itemCount){
			revert InvalidTokenId();
		}
        if (items[_tokenId].totalSupply > 0) {
            revert ItemInUse();
        }
		if(items[_tokenId].inUse = false){
			revert ItemRemoved();
		}
        items[_tokenId].inUse = false;
    }

    function getItemList() public view returns (GameItem[] memory _returnData) {
        _returnData = new GameItem[](itemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            _returnData[i] = items[i];
        }
    }

	//Tested
    function mint(uint256 _tokenId, uint256 _amount) external payable {
        if (items[_tokenId].mintCost == 0) {
            revert NotMintableItem();
        }
        if (!items[_tokenId].inUse) {
            revert ItemRemoved();
        }
        if (msg.value != items[_tokenId].mintCost * _amount) {
            revert InvalidTxValue();
        }
        items[_tokenId].totalSupply += _amount;
        if (items[_tokenId].maxSupply > 0 && items[_tokenId].totalSupply > items[_tokenId].maxSupply) {
            revert ExceedsMaxSupply();
        }
        _mint(msg.sender, _tokenId, _amount, "");
    }

    function transferToGame(
        address _from,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts
    ) external onlyInventoryContract {
        _burnBatch(_from, _tokenIds, _amounts);
        for (uint i = 0; i < _tokenIds.length; i++) {
            items[_tokenIds[i]].totalSupply -= _amounts[i];
        }
    }

    function transferToPlayer(
        address _to,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts
    ) external onlyInventoryContract {
        _mintBatch(_to, _tokenIds, _amounts, "");
        for (uint i = 0; i < _tokenIds.length; i++) {
            items[_tokenIds[i]].totalSupply += _amounts[i];
        }
    }

	//Tested internally
    function claimForPlayer(address _player, uint256 _tokenId, uint256 _amount) external onlyInventoryContract {
        if (items[_tokenId].maxSupply != 0 && items[_tokenId].totalSupply + _amount > items[_tokenId].maxSupply) {
            revert ExceedsMaxSupply();
        }
        if (!items[_tokenId].inUse) {
            revert ItemRemoved();
        }
        items[_tokenId].totalSupply++;
        _mint(_player, _tokenId, _amount, "");
    }

	//Tested
    function uri(uint256 _tokenId) public view override returns (string memory) {
        return items[_tokenId].uri;
    }

	//Tested internally
    function withdraw() external payable onlyInventoryContract {
        if (address(this).balance == 0) return;
        (bool transferResult, ) = treasury.call{value: address(this).balance}("");
        require(transferResult);
    }

	//Tested
    function walletOfOwner(address _player) external view returns (uint256[] memory _result) {
        _result = new uint256[](itemCount);
        for (uint i = 0; i < itemCount; i++) {
            _result[i] = balanceOf(_player, i);
        }
    }
}
