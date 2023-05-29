// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;
import "./interfaces/IERC721GameItem.sol";
import "../interfaces/IManagers.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";



contract ERC721GameInventory {
    using ERC165Checker for address;

    IERC721GameItem[] public inGameItems;
    IManagers public managers;

    address public authorizedAddress;
    address payable treasury;

    mapping(address => bool) public allowedItems;
    mapping(address => mapping(address => uint256[])) public playerItemsInGame;
    mapping(string => bool) public completedTransactions;

    struct ClaimDefinition {
        address itemAddress;
        bool claimed;
    }
    mapping(address => mapping(string => ClaimDefinition)) public userClaimDefinitionForItem;

    error InvalidItemAddress();
    error UsedPlayfabTxId();
    error ItemIsNotValid();
    error AlreadyClaimed();
    error NotAuthorized();
    error NoAllocation();
    error ItemInUse();

    event ChangeTreasuryAddress(address manager, address newAddress, bool approved);
    event AddItemToGameInventory(address player, string playfabTxId, address itemAddress, uint256 tokenId);
    event RemoveItemFromGameInventory(address player, string playfabTxId, address itemAddress, uint256 tokenId);
    event CreateNewItem(address itemAddress);
    event RemoveItem(address itemAddress);
    event Claim(address player, string playfabTxId, address itemAddress, uint256 tokenId);

    constructor(IManagers _managers, address _authorizedAddress, address payable _treasury) {
        managers = _managers;
        authorizedAddress = _authorizedAddress;
        treasury = _treasury;
    }

    //Modifiers
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

    //Write Functions
    function setAuthorizedAddress(address _newAddress) external onlyManager {
        authorizedAddress = _newAddress;
        for (uint256 i = 0; i < inGameItems.length; i++) {
            inGameItems[i].setAuthorizedAddress(_newAddress);
        }
    }

    function setTreasury(address payable _newAddress) external onlyManager {
        string memory _title = "Set Treasury Address";
        bytes memory _encodedValues = abi.encode(_newAddress);
        managers.approveTopic(_title, _encodedValues);
        bool _isApproved = managers.isApproved(_title, _encodedValues);
        if (_isApproved) {
            treasury = _newAddress;
            for (uint256 i = 0; i < inGameItems.length; i++) {
                inGameItems[i].setTreasury(_newAddress);
            }
            managers.deleteTopic(_title);
        }
        emit ChangeTreasuryAddress(msg.sender, _newAddress, _isApproved);
    }

    //Tested
    function addItemToGameInventory(address _itemAddress, uint256 _tokenId, string memory _playfabTxId) external {
        IERC721GameItem(_itemAddress).transferFrom(msg.sender, address(this), _tokenId);
        playerItemsInGame[msg.sender][_itemAddress].push(_tokenId);
        if (completedTransactions[_playfabTxId]) {
            revert UsedPlayfabTxId();
        }
        completedTransactions[_playfabTxId] = true;
        emit AddItemToGameInventory(msg.sender, _playfabTxId, _itemAddress, _tokenId);
    }

    //Tested
    function removeItemFromGameInventory(
        address _itemAddress,
        uint256 _tokenId,
        string calldata _playfabTxId
    ) external {
        if (completedTransactions[_playfabTxId]) {
            revert UsedPlayfabTxId();
        }

        IERC721GameItem(_itemAddress).transferFrom(address(this), msg.sender, _tokenId);
        uint256[] storage playerItems = playerItemsInGame[msg.sender][_itemAddress];
        for (uint256 i = 0; i < playerItems.length; i++) {
            if (playerItems[i] == _tokenId) {
                playerItems[i] = playerItems[playerItems.length - 1];
                playerItems.pop();
            }
        }
        completedTransactions[_playfabTxId] = true;
        emit RemoveItemFromGameInventory(msg.sender, _playfabTxId, _itemAddress, _tokenId);
    }

    //Tested
    function createNewItem(address _itemAddress) external onlyManager {
        if (!_itemAddress.supportsInterface(type(IERC721GameItem).interfaceId)) {
            revert InvalidItemAddress();
        }
        inGameItems.push(IERC721GameItem(_itemAddress));
        allowedItems[address(_itemAddress)] = true;
        emit CreateNewItem(_itemAddress);
    }

    //Tested
    function removeItem(address _itemAddress) external onlyManager {
        if (!allowedItems[_itemAddress]) revert ItemIsNotValid();

        allowedItems[_itemAddress] = false;
        for (uint256 i = 0; i < inGameItems.length; i++) {
            IERC721GameItem _item = inGameItems[i];
            if (address(_item) == _itemAddress) {
                if (_item.totalSupply() > 0) {
                    revert ItemInUse();
                }
                if (i != inGameItems.length - 1) {
                    inGameItems[i] = inGameItems[inGameItems.length - 1];
                }
                inGameItems.pop();
                emit RemoveItem(_itemAddress);

                break;
            }
        }
    }

    //Tested
    function setClaimDefinition(
        address _player,
        address _itemAddress,
        string calldata _playfabTxId
    ) external onlyAuthorizedAddress {
        if (completedTransactions[_playfabTxId]) {
            revert UsedPlayfabTxId();
        }
        userClaimDefinitionForItem[_player][_playfabTxId] = ClaimDefinition({
            itemAddress: _itemAddress,
            claimed: false
        });
    }

    //Tested
    function claim(string memory _playfabTxId) external {
        if (userClaimDefinitionForItem[msg.sender][_playfabTxId].itemAddress == address(0)) {
            revert NoAllocation();
        }
        if (userClaimDefinitionForItem[msg.sender][_playfabTxId].claimed == true) {
            revert AlreadyClaimed();
        }
        if (completedTransactions[_playfabTxId]) {
            revert UsedPlayfabTxId();
        }
        userClaimDefinitionForItem[msg.sender][_playfabTxId].claimed = true;
        IERC721GameItem(userClaimDefinitionForItem[msg.sender][_playfabTxId].itemAddress).claimForPlayer(msg.sender);
        completedTransactions[_playfabTxId] = true;
        emit Claim(
            msg.sender,
            _playfabTxId,
            userClaimDefinitionForItem[msg.sender][_playfabTxId].itemAddress,
            IERC721GameItem(userClaimDefinitionForItem[msg.sender][_playfabTxId].itemAddress).totalSupply()
        );
    }

    //Tested
    function withdraw() external payable onlyManager {
        for (uint256 i = 0; i < inGameItems.length; i++) {
            inGameItems[i].withdraw();
        }
    }

    //Read Functions
    //Tested
    function getPlayerItems(address _player, address _itemAddress) external view returns (uint256[] memory) {
        return playerItemsInGame[_player][_itemAddress];
    }

    //Tested
    function getPlayerHasItem(address _player, address _itemAddress, uint256 _tokenId) public view returns (bool) {
        uint256[] memory playerItems = playerItemsInGame[_player][_itemAddress];
        for (uint256 i = 0; i < playerItems.length; i++) {
            if (playerItems[i] == _tokenId) {
                return true;
            }
        }
        return false;
    }

    //Tested
    function getItemList() public view returns (IERC721GameItem[] memory) {
        return inGameItems;
    }
}
