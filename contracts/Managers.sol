// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Managers is Ownable {
    //Structs
    struct Source {
        address sourceAddress;
        string sourceName;
    }
    struct Topic {
        address source;
        string title;
        uint256 approveCount;
    }
    struct TopicApproval {
        address source;
        bool approved;
        bytes value;
    }

    //Storage Variables
    Topic[] public activeTopics;

    address public manager1;
    address public manager2;
    address public manager3;
    address public manager4;
    address public manager5;

    mapping(string => mapping(address => TopicApproval)) public managerApprovalsForTopic;
    mapping(address => Source) public trustedSources;

    //Custom Errors
    error ManagerAddressCannotBeAddedToTrustedSources();
    error SameAddressForManagers();
    error NotApprovedByManager();
    error CannotSetOwnAddress();
    error UntrustedSource();
    error TopicNotFound();
    error NotAuthorized();
    error ZeroAddress();
    error AlreadyVoted();

    //Events
    event AddTrustedSource(address addr, string name);
    event ApproveTopic(address by, string source, string title, bytes encodedValues);
    event CancelTopicApproval(address by, string title);
    event ChangeManagerAddress(address manager, string managerToChange, address newAddress, bool isApproved);
    event DeleteTopic(string title);

    constructor(address _manager1, address _manager2, address _manager3, address _manager4, address _manager5) {
        if (
            _manager1 == address(0) ||
            _manager2 == address(0) ||
            _manager3 == address(0) ||
            _manager4 == address(0) ||
            _manager5 == address(0)
        ) {
            revert ZeroAddress();
        }

        manager1 = _manager1;
        if (isManager(_manager2)) {
            revert SameAddressForManagers();
        }
        manager2 = _manager2;
        if (isManager(_manager3)) {
            revert SameAddressForManagers();
        }
        manager3 = _manager3;
        if (isManager(_manager4)) {
            revert SameAddressForManagers();
        }
        manager4 = _manager4;
        if (isManager(_manager5)) {
            revert SameAddressForManagers();
        }
        manager5 = _manager5;
        _addAddressToTrustedSources(address(this), "Managers");
    }

    //Modifiers
    modifier onlyManager(address _caller) {
        if (!isManager(_caller)) {
            revert NotAuthorized();
        }
        _;
    }

    modifier onlyTrustedSources(address _sender) {
        if (trustedSources[_sender].sourceAddress == address(0)) {
            revert UntrustedSource();
        }
        _;
    }

    //Write Functions
    function addAddressToTrustedSources(address _address, string memory _name) external onlyOwner {
        _addAddressToTrustedSources(_address, _name);
    }

    function approveTopic(
        string memory _title,
        bytes memory _encodedValues
    ) public onlyManager(tx.origin) onlyTrustedSources(msg.sender) {
        _approveTopic(_title, _encodedValues);
    }

    function cancelTopicApproval(string memory _title) public onlyManager(msg.sender) {
        (bool _titleExists, uint256 _topicIndex) = _indexOfTopic(_title);
        if (!_titleExists) {
            revert TopicNotFound();
        }
        if (!managerApprovalsForTopic[_title][msg.sender].approved) {
            revert NotApprovedByManager();
        }

        activeTopics[_topicIndex].approveCount--;
        if (activeTopics[_topicIndex].approveCount == 0) {
            _deleteTopic(_title);
        } else {
            managerApprovalsForTopic[_title][msg.sender].approved = false;
        }
        emit CancelTopicApproval(msg.sender, _title);
    }

    function deleteTopic(string memory _title) external onlyManager(tx.origin) onlyTrustedSources(msg.sender) {
        string memory _prefix = string.concat(trustedSources[msg.sender].sourceName, ": ");
        _title = string.concat(_prefix, _title);
        _deleteTopic(_title);
    }

    function changeManager1Address(address _newAddress) external onlyManager(msg.sender) {
        if (msg.sender == manager1) {
            revert CannotSetOwnAddress();
        }
        if (isManager(_newAddress)) {
            revert SameAddressForManagers();
        }

        string memory _title = "Change Manager 1 Address";
        bytes memory _encodedValues = abi.encode(_newAddress);
        _approveTopic(_title, _encodedValues);

        bool _isApproved = isApproved(_title, _encodedValues);
        if (_isApproved) {
            manager1 = _newAddress;
            _deleteTopic(string.concat("Managers: ", _title));
        }
        emit ChangeManagerAddress(msg.sender, "Manager1", _newAddress, _isApproved);
    }

    function changeManager2Address(address _newAddress) external onlyManager(msg.sender) {
        if (msg.sender == manager2) {
            revert CannotSetOwnAddress();
        }
        if (isManager(_newAddress)) {
            revert SameAddressForManagers();
        }

        string memory _title = "Change Manager 2 Address";
        bytes memory _encodedValues = abi.encode(_newAddress);
        _approveTopic(_title, _encodedValues);

        bool _isApproved = isApproved(_title, _encodedValues);
        if (_isApproved) {
            manager2 = _newAddress;
            _deleteTopic(string.concat("Managers: ", _title));
        }
        emit ChangeManagerAddress(msg.sender, "Manager2", _newAddress, _isApproved);
    }

    function changeManager3Address(address _newAddress) external onlyManager(msg.sender) {
        if (msg.sender == manager3) {
            revert CannotSetOwnAddress();
        }
        if (isManager(_newAddress)) {
            revert SameAddressForManagers();
        }

        string memory _title = "Change Manager 3 Address";
        bytes memory _encodedValues = abi.encode(_newAddress);
        _approveTopic(_title, _encodedValues);

        bool _isApproved = isApproved(_title, _encodedValues);
        if (_isApproved) {
            manager3 = _newAddress;
            _deleteTopic(string.concat("Managers: ", _title));
        }
        emit ChangeManagerAddress(msg.sender, "Manager3", _newAddress, _isApproved);
    }

    function changeManager4Address(address _newAddress) external onlyManager(msg.sender) {
        if (msg.sender == manager4) {
            revert CannotSetOwnAddress();
        }
        if (isManager(_newAddress)) {
            revert SameAddressForManagers();
        }

        string memory _title = "Change Manager 4 Address";
        bytes memory _encodedValues = abi.encode(_newAddress);
        _approveTopic(_title, _encodedValues);

        bool _isApproved = isApproved(_title, _encodedValues);
        if (_isApproved) {
            manager4 = _newAddress;
            _deleteTopic(string.concat("Managers: ", _title));
        }
        emit ChangeManagerAddress(msg.sender, "Manager4", _newAddress, _isApproved);
    }

    function changeManager5Address(address _newAddress) external onlyManager(msg.sender) {
        if (msg.sender == manager5) {
            revert CannotSetOwnAddress();
        }
        if (isManager(_newAddress)) {
            revert SameAddressForManagers();
        }

        string memory _title = "Change Manager 5 Address";
        bytes memory _encodedValues = abi.encode(_newAddress);
        _approveTopic(_title, _encodedValues);

        bool _isApproved = isApproved(_title, _encodedValues);
        if (_isApproved) {
            manager5 = _newAddress;
            _deleteTopic(string.concat("Managers: ", _title));
        }
        emit ChangeManagerAddress(msg.sender, "Manager5", _newAddress, _isApproved);
    }

    function _deleteTopic(string memory _title) private {
        (bool _titleExists, uint256 _topicIndex) = _indexOfTopic(_title);
        if (!_titleExists) {
            revert TopicNotFound();
        }
        delete managerApprovalsForTopic[_title][manager1];
        delete managerApprovalsForTopic[_title][manager2];
        delete managerApprovalsForTopic[_title][manager3];
        delete managerApprovalsForTopic[_title][manager4];
        delete managerApprovalsForTopic[_title][manager5];

        if (_topicIndex < activeTopics.length - 1) {
            activeTopics[_topicIndex] = activeTopics[activeTopics.length - 1];
        }
        activeTopics.pop();
        emit DeleteTopic(_title);
    }

    function _approveTopic(string memory _title, bytes memory _encodedValues) private {
        string memory _prefix = "";
        address _source;
        if (bytes(trustedSources[msg.sender].sourceName).length > 0) {
            _prefix = string.concat(trustedSources[msg.sender].sourceName, ": ");
            _source = trustedSources[msg.sender].sourceAddress;
        } else {
            if (isManager(msg.sender)) {
                _prefix = "Managers: ";
                _source = address(this);
            } else {
                revert("MANAGERS: Untrusted source");
            }
        }

        _title = string.concat(_prefix, _title);

        if (managerApprovalsForTopic[_title][tx.origin].approved) {
            revert AlreadyVoted();
        }

        managerApprovalsForTopic[_title][tx.origin].approved = true;
        managerApprovalsForTopic[_title][tx.origin].value = _encodedValues;
        managerApprovalsForTopic[_title][tx.origin].source = _source;

        (bool _titleExists, uint256 _topicIndex) = _indexOfTopic(_title);

        if (!_titleExists) {
            activeTopics.push(Topic({source: _source, title: _title, approveCount: 1}));
        } else {
            activeTopics[_topicIndex].approveCount++;
        }
        emit ApproveTopic(tx.origin, trustedSources[msg.sender].sourceName, _title, _encodedValues);
    }

    function _addAddressToTrustedSources(address _address, string memory _name) private {
        if (_address == address(0)) {
            revert ZeroAddress();
        }
        if (isManager(_address)) {
            revert ManagerAddressCannotBeAddedToTrustedSources();
        }
        trustedSources[_address].sourceAddress = _address;
        trustedSources[_address].sourceName = _name;
        emit AddTrustedSource(_address, _name);
    }

    //Read Functions
    function isManager(address _address) public view returns (bool) {
        return (_address == manager1 ||
            _address == manager2 ||
            _address == manager3 ||
            _address == manager4 ||
            _address == manager5);
    }

    function isTrustedSource(address _address) public view returns (bool) {
        return trustedSources[_address].sourceAddress != address(0);
    }

    function getActiveTopics() public view returns (Topic[] memory) {
        return activeTopics;
    }

    function isApproved(string memory _title, bytes memory _value) public view returns (bool _isApproved) {
        string memory _prefix = "";
        if (bytes(trustedSources[msg.sender].sourceName).length > 0) {
            _prefix = string.concat(trustedSources[msg.sender].sourceName, ": ");
        } else {
            if (isManager(msg.sender)) {
                _prefix = "Managers: ";
            } else {
                revert UntrustedSource();
            }
        }
        _title = string.concat(_prefix, _title);
        bytes memory _manager1Approval = managerApprovalsForTopic[_title][manager1].value;
        bytes memory _manager2Approval = managerApprovalsForTopic[_title][manager2].value;
        bytes memory _manager3Approval = managerApprovalsForTopic[_title][manager3].value;
        bytes memory _manager4Approval = managerApprovalsForTopic[_title][manager4].value;
        bytes memory _manager5Approval = managerApprovalsForTopic[_title][manager5].value;

        uint256 _totalValidVotes = 0;

        _totalValidVotes += managerApprovalsForTopic[_title][manager1].approved &&
            keccak256(_manager1Approval) == keccak256(_value)
            ? 1
            : 0;
        _totalValidVotes += managerApprovalsForTopic[_title][manager2].approved &&
            keccak256(_manager2Approval) == keccak256(_value)
            ? 1
            : 0;
        _totalValidVotes += managerApprovalsForTopic[_title][manager3].approved &&
            keccak256(_manager3Approval) == keccak256(_value)
            ? 1
            : 0;
        _totalValidVotes += managerApprovalsForTopic[_title][manager4].approved &&
            keccak256(_manager4Approval) == keccak256(_value)
            ? 1
            : 0;
        _totalValidVotes += managerApprovalsForTopic[_title][manager5].approved &&
            keccak256(_manager5Approval) == keccak256(_value)
            ? 1
            : 0;
        _isApproved = _totalValidVotes >= 3;
    }

    function getManagerApprovalsForTitle(
        string calldata _title
    ) public view returns (TopicApproval[] memory _returnData) {
        _returnData = new TopicApproval[](5);
        _returnData[0] = managerApprovalsForTopic[_title][manager1];
        _returnData[1] = managerApprovalsForTopic[_title][manager2];
        _returnData[2] = managerApprovalsForTopic[_title][manager3];
        _returnData[3] = managerApprovalsForTopic[_title][manager4];
        _returnData[4] = managerApprovalsForTopic[_title][manager5];
    }

    function _compareStrings(string memory a, string memory b) private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    function _indexOfTopic(string memory _element) private view returns (bool found, uint256 i) {
        for (i = 0; i < activeTopics.length; i++) {
            if (_compareStrings(activeTopics[i].title, _element)) {
                return (true, i);
            }
        }
        return (false, 0); //Cannot return -1 with type uint256. For that check the first parameter is true or false always.
    }
}
