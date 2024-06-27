// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

contract Helper {
    function calculateAndDistribute(
        address staking,
        uint256 offset,
        uint256 count
    ) external {
        Staking(staking).calculateProfit(offset, count);
        Pool(Staking(staking).currentPool()).distributeProfit();
    }
}

interface Staking {
    function calculateProfit(uint256 offset, uint256 count) external;
    function currentPool() external view returns (address);
}

interface Pool {
    function distributeProfit() external;
}
