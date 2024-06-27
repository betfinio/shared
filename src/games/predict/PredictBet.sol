// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "openzeppelin/access/Ownable.sol";
import "../../BetInterface.sol";
import "../../Common.sol";

contract PredictBet is Ownable, BetInterface {
    address private player;
    address private game;
    uint256 private amount;
    bool private side;
    uint256 private immutable created;

    // 1 - registered - round starts
    // 2 - won - round ends
    // 3 - lost - round ends
    // 4 - draw - round ends
    // 5 - refunded - round ends
    uint256 private status;
    uint256 private round;
    uint256 private result;
    uint256 private bonus;
    address private predictGame;

    Common.Answer private start;
    Common.Answer private end;

    constructor(
        address _player,
        uint256 _amount,
        uint256 _status,
        address _game,
        uint256 _round,
        address _predictGame,
        bool _side
    ) Ownable(_msgSender()) {
        created = block.timestamp;
        player = _player;
        amount = _amount;
        status = _status;
        game = _game;
        round = _round;
        predictGame = _predictGame;
        side = _side;
    }

    function getRound() public view returns (uint256) {
        return round;
    }

    function getPlayer() external view override returns (address) {
        return player;
    }

    function getGame() external view override returns (address) {
        return game;
    }

    function getAmount() external view override returns (uint256) {
        return amount;
    }

    function getStatus() external view override returns (uint256) {
        return status;
    }

    function getCreated() external view override returns (uint256) {
        return created;
    }

    function getResult() external view override returns (uint256) {
        return result;
    }

    function getSide() external view returns (bool) {
        return side;
    }

    function getBetInfo()
        external
        view
        override
        returns (address, address, uint256, uint256, uint256, uint256)
    {
        return (player, game, amount, result, status, created);
    }

    function setRound(uint256 _round) external onlyOwner {
        round = _round;
    }

    function setStatus(uint256 _status) external onlyOwner {
        status = _status;
    }

    function setAmount(uint256 _amount) external onlyOwner {
        amount = _amount;
    }

    function setPlayer(address _player) external onlyOwner {
        player = _player;
    }

    function setGame(address _game) external onlyOwner {
        game = _game;
    }

    function setSide(bool _side) external onlyOwner {
        side = _side;
    }

    function setBonus(uint256 _bonus) external onlyOwner {
        bonus = _bonus;
    }

    function getBonus() external view returns (uint256) {
        return bonus;
    }

    function setResult(uint256 _result) external onlyOwner {
        result = _result;
    }

    function getPredictGame() external view returns (address) {
        return predictGame;
    }

    function setPredictGame(address _predictGame) external onlyOwner {
        predictGame = _predictGame;
    }
}
