// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "./interfaces/IERC721GameItem.sol";
import "../interfaces/IManagers.sol";



contract ERC721GameItem is ERC721Enumerable, ERC165Storage, IERC721GameItem {
    using Strings for uint256;

    IManagers public managers;

    uint256 public mintCost;
    uint256 public maxSupply; //0 = unlimited

    address inGameItemsInventory;
    address authorizedAddress;
    address payable treasury;

    string public publicUri;

    mapping(uint256 => string) tokenURIs;
    mapping(address => uint256[]) userTokens;

    error MustBeGreaterThanTotalSupply();
    error ExceedsMaxSupply();
    error InvalidParameter();
    error NotEnoughValue();
    error NotAuthorized();
    error NotMintable();

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _publicUri,
        uint256 _mintCost,
        uint256 _maxSupply,
        address _inGameItemsInventory,
        address _authorizedAddress,
        address payable _treasury,
        IManagers _managers
    ) ERC721(_name, _symbol) {
        managers = _managers;
        mintCost = _mintCost;
        maxSupply = _maxSupply;
        publicUri = _publicUri;
        inGameItemsInventory = _inGameItemsInventory;
        authorizedAddress = _authorizedAddress;
        treasury = _treasury;

        _registerInterface(type(IERC721GameItem).interfaceId);
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
	function setPublicUri(string calldata _publicUri) external onlyManager{
		 if (bytes(_publicUri).length == 0) {
            revert InvalidParameter();
        }
		publicUri = _publicUri;
	}

	//Tested
    function setTokenUri(uint256 _tokenId, string calldata _uri) external onlyAuthorizedAddress {
        if (bytes(_uri).length == 0) {
            tokenURIs[_tokenId] = publicUri;
        } else {
            tokenURIs[_tokenId] = _uri;
        }
    }

    function setMintCost(uint256 _newCost) external onlyManager {
        mintCost = _newCost;
    }

    function setMaxSupply(uint256 _newMaxSupply) external onlyManager {
        if (_newMaxSupply != 0 && _newMaxSupply < totalSupply()) {
            revert MustBeGreaterThanTotalSupply();
        }
        maxSupply = _newMaxSupply;
    }

	//Tested
    function mint() external payable {
        if (mintCost == 0) {
            revert NotMintable();
        }
        if (msg.value != mintCost) {
            revert NotEnoughValue();
        }
        if (maxSupply != 0 && totalSupply() == maxSupply) {
            revert ExceedsMaxSupply();
        }
        _safeMint(msg.sender, totalSupply() + 1);
    }

	//Tested internally
    function claimForPlayer(address _player) external onlyInventoryContract {
        if (maxSupply != 0 && totalSupply() == maxSupply) {
            revert ExceedsMaxSupply();
        }
        _safeMint(_player, totalSupply() + 1);
    }

	//Tested
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        _requireMinted(_tokenId);

        if (bytes(tokenURIs[_tokenId]).length > 0) {
            return tokenURIs[_tokenId];
        } else {
            return publicUri;
        }
    }

	//Tested
    function walletOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

	//Tested Internally
    function withdraw() external payable onlyInventoryContract {
        if (address(this).balance == 0) return;
        (bool transferResult, ) = treasury.call{value: address(this).balance}("");
        require(transferResult);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, IERC165, ERC165Storage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
