// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./Pass.sol";

contract Multimint {
    function multimint(address[] calldata addresses, address[] calldata parents, address pass) external {
        for (uint256 i = 0; i < addresses.length; i++) {
            Pass(pass).mint(addresses[i], msg.sender, parents[i]);
        }
    }
}
