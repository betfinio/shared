// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "openzeppelin/access/AccessControl.sol";
import "../../GameInterface.sol";
import "../../CoreInterface.sol";
import "./PredictGame.sol";

/**
 * Errors used in this contract
 *
 * P01 - access error, only Core address is allowed
 * P02 - invalid input(amount) data to place a bet
 * P03 - invalid input(predict game) data to place a bet
 * P04 - invalid predict game
 * P05 - invalid bonus when creating new predict game
 * P06 - invalid duration when creating new predict game
 * P07 - invalid interval when creating new predict game
 * P08 - invalid threshold when creating new predict game
 * P09 - staking contract is not registered in Core
 * P10 - invalid recovery interval
 */
contract Predict is AccessControl, GameInterface {
    bytes32 public constant TIMELOCK = keccak256("TIMELOCK");

    uint256 public immutable created;

    CoreInterface public immutable core;

    address public immutable staking;

    event GameCreated(address indexed game);
    event GameDeactivated(address indexed game);
    event GameActivated(address indexed game);

    address[] private games;

    mapping(address => bool) internal isGame;

    constructor(address _core, address _staking, address _admin) {
        created = block.timestamp;
        core = CoreInterface(_core);
        require(core.isStaking(_staking), "P09");
        staking = _staking;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function addGame(
        address _dataFeed,
        string memory _symbol,
        uint256 _interval,
        uint256 _bonus,
        uint256 _duration,
        uint256 _threshold,
        uint256 _recovery
    ) public onlyRole(TIMELOCK) returns (address) {
        require(_bonus < 100_00, "P05");
        require(_duration >= 2, "P06");
        require(_interval > 0, "P07");
        require(_threshold >= 30, "P08");
        require(_recovery > 0, "P08");
        PredictGame game = new PredictGame(
            _dataFeed,
            _symbol,
            _interval,
            _bonus,
            _duration,
            _threshold,
            _recovery
        );
        game.activate();
        games.push(address(game));
        isGame[address(game)] = true;
        emit GameCreated(address(game));
        return address(game);
    }

    function deactivate(address _game) external onlyRole(TIMELOCK) {
        require(isGame[_game], "P04");
        PredictGame(_game).deactivate();
        emit GameDeactivated(_game);
    }

    function activate(address _game) external onlyRole(TIMELOCK) {
        require(isGame[_game], "P04");
        PredictGame(_game).activate();
        emit GameActivated(_game);
    }

    function getGames() public view returns (address[] memory) {
        return games;
    }

    function placeBet(
        uint256 _amount,
        bool _side,
        address _game,
        address _player
    ) internal returns (address) {
        ERC20(core.token()).transfer(
            _game,
            _amount - (_amount * core.fee()) / 100_00
        );
        return PredictGame(_game).placeBet(_amount, _side, _player);
    }

    function placeBet(
        address _player,
        uint256 _totalAmount,
        bytes calldata _data
    ) external override returns (address) {
        require(address(core) == _msgSender(), "P01");
        (uint256 _amount, bool _side, address _game) = abi.decode(
            _data,
            (uint256, bool, address)
        );
        require(_totalAmount == _amount, "P02");
        require(isGame[_game], "P03");
        return placeBet(_amount, _side, _game, _player);
    }

    function getAddress() public view override returns (address) {
        return address(this);
    }

    function getVersion() public view override returns (uint256) {
        return created;
    }

    function getFeeType() public pure override returns (uint256) {
        return 0;
    }

    function getStaking() public view override returns (address) {
        return staking;
    }
}
