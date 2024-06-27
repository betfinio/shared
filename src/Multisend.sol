// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "openzeppelin/token/ERC20/ERC20.sol";

contract Multisend {
    uint256 public immutable sendAmount = 0;
    constructor(uint256 _sendAmount) {
        sendAmount = _sendAmount;
    }
    function multisend(address[] calldata addresses, address token) external {
        for (uint256 i = 0; i < addresses.length; i++) {
            ERC20(token).transferFrom(msg.sender, addresses[i], sendAmount);
        }
    }
}
