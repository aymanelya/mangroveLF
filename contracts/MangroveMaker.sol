// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "hardhat/console.sol";

import "./UniswapV2Library.sol";
import "./interfaces/IUniswapV2Factory.sol";

contract MangroveMaker {
    // Declare your variables
    address public mgv;
    uint public spread;
    uint public volume;
    uint public tenacity;
    address[][] public pairs;
    address public otherDexFactory;
    uint public otherDexFees;

    // This event is used to log updates
    event stratParamsUpdated(
        address indexed _mgv,
        uint _spread,
        uint _volume,
        uint _tenacity,
        address _otherDexFactory,
        uint _otherDexFees
    );

    // Constructor to initialize default values (volume respresented by the first token of each pair)
    constructor(
        address _mgv,
        uint _spread,
        uint _volume,
        uint _tenacity,
        address[][] memory _pairs,
        address _otherDexFactory,
        uint _otherDexFees
    ) {
        mgv = _mgv;
        spread = _spread;
        volume = _volume;
        tenacity = _tenacity;
        pairs = _pairs;
        otherDexFactory = _otherDexFactory;
        otherDexFees = _otherDexFees;
    }

    // This function allows updating the values of your variables
    function updateData(
        address _mgv,
        uint _spread,
        uint _volume,
        uint _tenacity,
        address[][] memory _pairs,
        address _otherDexFactory,
        uint _otherDexFees
    ) public {
        // You could add conditions here to restrict who can call this function
        mgv = _mgv;
        spread = _spread;
        volume = _volume;
        tenacity = _tenacity;
        pairs = _pairs;
        otherDexFactory = _otherDexFactory;
        otherDexFees = _otherDexFees;

        emit stratParamsUpdated(
            mgv,
            spread,
            volume,
            tenacity,
            otherDexFactory,
            otherDexFees
        );
    }

    function getTrackedPairs() public view returns (address[][] memory) {
        return pairs;
    }

    function createOffers() public view {
        // console.log(volume);
        // console.log("here1",pairs.length - 1);

        for (uint i = 0; i < pairs.length; i++) {
            // getting reserves from otherDex
            require(
                (address(pairs[i][0]) != address(0)) &&
                    (address(pairs[i][1]) != address(0)),
                "TOKEN ADDRESS IS ZERO"
            );

            address pairAddress = IUniswapV2Factory(otherDexFactory).getPair(
                pairs[i][0],
                pairs[i][1]
            );
            console.log(pairAddress);
            require(pairAddress != address(0), "PAIR_NOT_FOUND");
            (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pairAddress)
                .getReserves();
            console.log(reserve0, reserve1);
            require(
                reserve0 > 0 && reserve1 > 0,
                "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
            );

            address[] memory path = new address[](2);
            path[0] = pairs[i][0];
            path[1] = pairs[i][1];
            address[] memory pairPath = new address[](1);
            pairPath[0] = pairAddress;
            uint[] memory fees = new uint[](1);
            fees[0] = 30;

            // calculate amount of token1 expected when selling ($volume) of token0
            uint[] memory amounts = UniswapV2Library.getAmountsOut(
                volume,
                path,
                pairPath,
                fees
            );
            console.log(volume, "=>", amounts[amounts.length - 1]);
            // calculate amount of token0 necessary to buy ($volume) of token0
            path[0] = pairs[i][1];
            path[1] = pairs[i][0];
            uint[] memory amounts2 = UniswapV2Library.getAmountsIn(
                volume,
                path,
                pairPath,
                fees
            );
            console.log(amounts2[0], "=>", volume);
        }
    }
}
