// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";

struct ClaimData {
    string playfabId;
    string playfabTxId;
    address player;
    uint256 amount;
	uint256 claimTime;
}

interface IWithdrawClaim {
    function setAuthorizedAddress(address _newAddress) external;

    function withdrawTokens(address _receiver) external;

    function createWithdrawDefinition(
        uint256 _startTime,
        bytes32 _merkleRootHash,
        uint256 _totalAmount,
        address _nextAuthorizedAddress
    ) external;

    function claimTokens(
        string calldata _playfabId,
        string calldata _playfabTxId,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external;

    function getClaimRecords(uint256 _period) external view returns (ClaimData[] memory _claimRecords);
}
