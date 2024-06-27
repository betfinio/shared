// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC20/ERC20.sol";

contract Vesting is Ownable {
    // mapping of time to amount
    mapping(uint256 => uint256) locks;
    // mapping of time to claimed status
    mapping(uint256 => bool) claimed;

    address public token;

    event Claimed(uint256 indexed time, uint256 indexed amount);
    event Locked(uint256 indexed time, uint256 indexed amount);

    constructor(address _token, address _owner) Ownable(_owner) {
        token = _token;
    }

    function claim(uint256 time) external onlyOwner {
        require(locks[time] > 0, "NOTHING");
        require(block.timestamp >= time, "LOCKED");
        require(claimed[time] == false, "CLAIMED");
        claimed[time] = true;
        ERC20(token).transfer(owner(), locks[time]);
        emit Claimed(time, locks[time]);
    }

    
    function lock(uint256 time, uint256 amount) external onlyOwner {
        lockInternal(time, amount);
    }

    function lockBatch(
        uint256[] calldata times,
        uint256[] calldata amounts
    ) external onlyOwner {
        require(times.length == amounts.length, "INVALID");
        for (uint256 i = 0; i < times.length; i++) {
            lockInternal(times[i], amounts[i]);
        }
    }

    function lockInternal(uint256 time, uint256 amount) internal {
        require(locks[time] == 0, "LOCKED");
        ERC20(token).transferFrom(owner(), address(this), amount);
        locks[time] = amount;
        emit Locked(time, amount);
    }

}
