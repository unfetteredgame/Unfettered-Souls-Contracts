// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;


struct ClaimData {
    address walletAddress;
    uint256 amount;
	uint256 time;
}

interface IAirdrop {
    function claimTokens(uint256 _amount, bytes32[] calldata _merkleProof) external;

    function createNewAirdrop(
        bytes32 _merkleRootHash,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _endTime,
		uint256 _rewardOwnerCount
    ) external;

    function getClaimRecords(uint256 _period) external view returns (ClaimData[] memory _claimRecords);
}
