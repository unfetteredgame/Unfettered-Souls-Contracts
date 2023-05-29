// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

struct StakeData {
    uint256 amount;
    uint256 stakeDate;
    uint256 releaseDate;
    uint256 percentage;
    uint16 monthToStake;
    bool withdrawn;
    bool emergencyWithdrawn;
    uint256 withdrawTime;
}

interface IStaking {
    function changeMinimumStakingAmount(uint256 _newAmount) external;

    function stake(uint256 _amount, uint8 _monthToStake) external;

    function emergencyWithdrawStake(uint256 _stakeIndex) external;

    function withdrawStake(uint256 _stakeIndex) external;

    function pause() external;

    function getTotalBalance() external view returns (uint256);

    function fetchStakeDataForAddress(address _address) external view returns (StakeData[] memory);

    function fetchOwnStakeData() external view returns (StakeData[] memory);

    function fetchStakeRewardForAddress(address _address, uint256 _stakeIndex)
        external
        view
        returns (uint256 _totalAmount, uint256 _penaltyAmount);

    function fetchStakeReward(uint256 _stakeIndex) external view returns (uint256 _totalAmount, uint256 _penaltyAmount);

    function fetchActiveStakers() external view returns (address[] memory);
   
    function fetchAllStakers() external view returns (address[] memory);
}
