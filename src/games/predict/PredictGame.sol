// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "chainlink/interfaces/AggregatorV3Interface.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import "./PredictBet.sol";
import "./Predict.sol";

/**
 * Errors used in this contract
 *
 * PG01 - game is not active
 * PG02 - round is full
 * PG03 - round is not finished to calculate
 * PG04 - data did not change since start
 * PG05 - data do not exists for start or end of round
 * PG06 - start data are not acceptable
 * PG07 - round already calculated
 * PG08 - round has no bets
 * PG09 - end data are not acceptable
 * PG10 - recovery is possible after 1 day of round start
 */
contract PredictGame is Ownable {
    AggregatorV3Interface public immutable dataFeed;
    Predict public immutable predict;
    ERC20 public immutable token;
    uint256 public immutable interval;
    uint256 public immutable bonus;
    string public symbol;
    bool public active;
    uint256 public immutable duration;
    uint256 public immutable threshold;
    uint256 public immutable recovery;

    mapping(uint256 => PredictBet[]) public bets;
    mapping(uint256 => PredictBet[]) public longBets;
    mapping(uint256 => PredictBet[]) public shortBets;
    mapping(uint256 => bool) public roundCalculated;
    mapping(uint256 => uint256) public longPool; // round => long pool
    mapping(uint256 => uint256) public shortPool; // round => short pool

    mapping(uint256 => Common.Answer) public start;
    mapping(uint256 => Common.Answer) public end;

    event BetCreated(
        address indexed player,
        uint256 indexed round,
        uint256 amount
    );
    event RoundCreated(uint256 indexed round);
    event RoundCalculated(uint256 indexed round);
    event RoundRecevered(uint256 indexed round);

    constructor(
        address _dataFeed,
        string memory _symbol,
        uint256 _interval,
        uint256 _bonus,
        uint256 _duration,
        uint256 _threshold,
        uint256 _recovery
    ) Ownable(_msgSender()) {
        dataFeed = AggregatorV3Interface(_dataFeed);
        symbol = _symbol;
        interval = _interval;
        threshold = _threshold;
        active = false;
        bonus = _bonus;
        duration = _duration;
        predict = Predict(_msgSender());
        token = ERC20(predict.core().token());
        recovery = _recovery;
    }

    function getCurrentRound() public view returns (uint256) {
        return block.timestamp / interval;
    }

    function placeBet(
        uint256 amount,
        bool side,
        address player
    ) public onlyOwner returns (address) {
        require(active, "PG01");
        uint256 round = block.timestamp / interval;
        require(bets[round].length <= 400, "PG02");
        PredictBet bet = new PredictBet(
            player,
            amount,
            1,
            address(predict),
            round,
            address(this),
            side
        );
        bets[round].push(bet);
        if (side) {
            longPool[round] += amount;
        } else {
            shortPool[round] += amount;
        }
        if (bets[round].length == 1) {
            emit RoundCreated(round);
        }
        return address(bet);
    }

    function calculateBets(
        uint256 round,
        uint80 _startRoundId,
        uint80 _endRoundId
    ) external returns (uint256 count) {
        // revert if round is not finished
        require((round + duration) * interval <= block.timestamp, "PG03");
        // revert if round is already calculated
        require(roundCalculated[round] == false, "PG07");
        require(bets[round].length > 0, "PG08");
        // fetch price at the start of round
        (
            uint80 startRoundId,
            int256 startAnswer,
            uint256 startTimestamp,
            ,

        ) = dataFeed.getRoundData(_startRoundId);
        // fetch price at the end of round
        (
            uint80 endRoundId,
            int256 endAnswer,
            uint256 endTimestamp,
            ,

        ) = dataFeed.getRoundData(_endRoundId);
        // revert if no data for start or end
        // revert if price's rounds are the same - means that price hasn't changed
        require(endRoundId != startRoundId, "PG04");
        // check if start timestamp is acceptable
        if (
            ((round * interval) - threshold > startTimestamp) ||
            ((round * interval) + threshold < startTimestamp)
        ) {
            revert("PG06");
        }
        // check if end timestamp is acceptable
        if (
            (((round + duration) * interval) - threshold > endTimestamp) ||
            (((round + duration) * interval) + threshold < endTimestamp)
        ) {
            revert("PG09");
        }

        // update start and end price
        start[round] = Common.Answer(startRoundId, startAnswer, startTimestamp);
        end[round] = Common.Answer(endRoundId, endAnswer, endTimestamp);
        // emit event that round is calculated
        emit RoundCalculated(round);
        // mark round as calculated
        roundCalculated[round] = true;
        // calculate results if long/short/draw
        if (startAnswer < endAnswer) return calculateLongResult(round);
        if (startAnswer > endAnswer) return calculateShortResult(round);
        return calculateDrawResult(round);
    }

    function calculateDrawResult(
        uint256 round
    ) private returns (uint256 count) {
        for (uint256 i = 0; i < bets[round].length; i++) {
            PredictBet _bet = bets[round][i];
            // ignore bets, that are calculated already
            if (_bet.getStatus() != 1) continue;
            // set status to draw
            _bet.setStatus(4);
            // calculate amount to return
            uint256 amount = (_bet.getAmount() *
                (100_00 - predict.core().fee())) / 100_00;
            // return amount to player
            token.transfer(_bet.getPlayer(), amount);
            count++;
        }
        return count;
    }

    function calculateLongResult(
        uint256 round
    ) internal returns (uint256 count) {
        return calculateBets(round, true);
    }

    function calculateShortResult(
        uint256 round
    ) internal returns (uint256 count) {
        return calculateBets(round, false);
    }

    function calculateBets(
        uint256 round,
        bool winSide
    ) private returns (uint256 count) {
        uint256 longs = longPool[round];
        uint256 shorts = shortPool[round];
        if (longs == 0 || shorts == 0) {
            refund(round);
            return 0;
        }
        // calculate pool without fee
        uint256 pool = ((longs + shorts) * (100_00 - predict.core().fee())) /
            100_00;
        // calculate bonus pool
        uint256 bonusPool = (pool * bonus) / 100_00;
        // calculate pool without bonus
        uint256 winPool = pool - bonusPool;
        // calculate bonus stakes
        (uint256 longStakes, uint256 shortStakes) = getTotalBonusStakes(round);
        // get bets count
        uint256 betsCount = bets[round].length;
        // 3. calculate winners
        for (uint256 i = 0; i < betsCount; i++) {
            PredictBet bet = bets[round][i];
            uint256 amount = bet.getAmount();
            // ignore bets that are not registered - already calculated
            if (bet.getStatus() != 1) continue;
            count++;
            // set status to lost if bet is not on winning side
            if (bet.getSide() != winSide) {
                bet.setStatus(3);
                continue;
            }
            // calculate winnings
            uint256 winnings = (winPool * amount) / (winSide ? longs : shorts);
            // calculate bonus winnings
            uint256 bonusWinnings = (bonusPool * amount * (betsCount - i)) /
                (winSide ? longStakes : shortStakes);
            bet.setResult(winnings);
            bet.setBonus(bonusWinnings);
            bet.setStatus(2);
            token.transfer(bet.getPlayer(), winnings + bonusWinnings);
        }
        return count;
    }

    function refund(uint256 round) private {
        for (uint256 i = 0; i < bets[round].length; i++) {
            PredictBet bet = bets[round][i];
            if (bet.getStatus() == 1) {
                bet.setStatus(5);
                uint amount = (bet.getAmount() *
                    (100_00 - predict.core().fee())) / 100_00;
                token.transfer(bet.getPlayer(), amount);
            }
        }
    }

    function getPool(
        uint256 round
    ) external view returns (uint256 longs, uint256 shorts) {
        return (longPool[round], shortPool[round]);
    }

    function getTotalBonusStakes(
        uint256 round
    ) public view returns (uint256 longs, uint256 shorts) {
        for (uint256 i = 0; i < bets[round].length; i++) {
            if (bets[round][i].getSide()) {
                longs += bets[round][i].getAmount() * (bets[round].length - i);
            } else {
                shorts += bets[round][i].getAmount() * (bets[round].length - i);
            }
        }
        return (longs, shorts);
    }

    function getRoundBets(
        uint256 round
    ) public view returns (uint256 count, address[] memory) {
        if (round == 0) round = getCurrentRound();
        address[] memory result = new address[](bets[round].length);
        for (uint256 i = 0; i < bets[round].length; i++) {
            result[i] = address(bets[round][i]);
        }
        return (bets[round].length, result);
    }

    function getPlayerBets(
        address player,
        uint256 round
    ) public view returns (uint256 count, address[] memory) {
        if (round == 0) round = getCurrentRound();
        if (bets[round].length == 0) {
            return (0, new address[](0));
        }
        for (uint256 i = 0; i < bets[round].length; i++) {
            if (bets[round][i].getPlayer() == player) {
                count++;
            }
        }
        address[] memory result = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < bets[round].length; i++) {
            if (bets[round][i].getPlayer() == player) {
                result[index] = address(bets[round][i]);
                index++;
            }
        }
        return (count, result);
    }

    function roundRecovery(uint256 round) external {
        require(block.timestamp > (round * interval + recovery), "PG10");
        require(roundCalculated[round] == false, "PG07");
        refund(round);
        emit RoundRecevered(round);
    }

    function activate() public onlyOwner {
        active = true;
    }

    function deactivate() public onlyOwner {
        active = false;
    }
}
