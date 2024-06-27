// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

library Common {
    struct Answer {
        uint80 roundId;
        int256 answer;
        uint256 timestamp;
    }
}
