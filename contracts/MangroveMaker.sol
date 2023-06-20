// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
import "hardhat/console.sol";

import "./UniswapV2Library.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";

import {Direct} from "./mgv_src/strategies/offer_maker/abstract/Direct.sol";
import {ILiquidityProvider} from "./mgv_src/strategies/interfaces/ILiquidityProvider.sol";
import {TransferLib} from "./mgv_src/strategies/utils/TransferLib.sol";
import {MangroveOffer} from "./mgv_src/strategies/MangroveOffer.sol";
import {IMangrove} from "./mgv_src/IMangrove.sol";
import {IERC20, MgvLib, MgvStructs, IMaker} from "./mgv_src/MgvLib.sol";

// import {Direct} from "mgv_src/strategies/offer_maker/abstract/Direct.sol";
// import {ILiquidityProvider} from "mgv_src/strategies/interfaces/ILiquidityProvider.sol";
// import {TransferLib} from "mgv_src/strategies/utils/TransferLib.sol";
// import {MangroveOffer} from "mgv_src/strategies/MangroveOffer.sol";
// import {IMangrove} from "mgv_src/IMangrove.sol";
// import {IERC20, MgvLib, MgvStructs, IMaker} from "mgv_src/MgvLib.sol";



contract MangroveMaker is Direct, ILiquidityProvider {
    // Declare your variables
    IMangrove mgv;
    uint[] public spread;
    uint[] public volume;
    uint[] public tenacity;
    address[][] public pairs;
    address public otherDexFactory;
    address public otherDexRouter;
    uint public otherDexFees;

    uint[][] public offerLists;

    // Constructor to initialize default values (volume respresented by the first token of each pair)
    constructor(
        IMangrove _mgv,
        uint[] memory _spread,
        uint[] memory _volume,
        uint[] memory _tenacity,
        address[][] memory _pairs,
        address _otherDexFactory,
        address _otherDexRouter,
        uint _otherDexFees,
        address admin
    ) Direct(_mgv, NO_ROUTER, 100_000, admin) {
        mgv = _mgv;
        spread = _spread;
        volume = _volume;
        tenacity = _tenacity;
        pairs = _pairs;
        otherDexFactory = _otherDexFactory;
        otherDexRouter = _otherDexRouter;
        otherDexFees = _otherDexFees;

        offerLists = new uint[][](pairs.length);
        for (uint i = 0; i < pairs.length; i++) {
            offerLists[i] = new uint[](0);
        }
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "EXPIRED");
        _;
    }

    // This function allows updating the values of your variables
    function updateParams(
        uint[] memory _spread,
        uint[] memory _volume,
        uint[] memory _tenacity,
        address[][] memory _pairs,
        address _otherDexFactory,
        address _otherDexRouter,
        uint _otherDexFees
    ) public {
        // You could add conditions here to restrict who can call this function
        spread = _spread;
        volume = _volume;
        tenacity = _tenacity;
        pairs = _pairs;
        otherDexFactory = _otherDexFactory;
        otherDexRouter = _otherDexRouter;
        otherDexFees = _otherDexFees;

        offerLists = new uint[][](pairs.length);
        for (uint i = 0; i < pairs.length; i++) {
            offerLists[i] = new uint[](0);
        }
    }

    function getTrackedPairs() public view returns (address[][] memory) {
        return pairs;
    }

    function getOfferLists() public view returns (uint[][] memory) {
        return offerLists;
    }

    function createInitialOffers() public payable onlyAdmin {
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
            // (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pairAddress)
            //     .getReserves();
            // console.log(reserve0, reserve1);
            // require(
            //     reserve0 > 0 && reserve1 > 0,
            //     "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
            // );

            address[] memory path = new address[](2);
            path[0] = pairs[i][1];
            path[1] = pairs[i][0];
            address[] memory pairPath = new address[](1);
            pairPath[0] = pairAddress;
            uint[] memory fees = new uint[](1);
            fees[0] = otherDexFees;

            // calculate amount of token1 expected when selling ($volume) of token0
            uint[] memory amounts = UniswapV2Library.getAmountsOut(
                volume[i],
                path,
                pairPath,
                fees
            );
            console.log(path[0], path[1]);
            console.log(volume[i], "=>", amounts[amounts.length - 1]);
            // calculate amount of token0 necessary to buy ($volume) of token0
            // path[0] = pairs[i][1];
            // path[1] = pairs[i][0];
            // uint[] memory amounts2 = UniswapV2Library.getAmountsIn(
            //     volume[i],
            //     path,
            //     pairPath,
            //     fees
            // );
            // console.log(amounts2[0], "=>", volume[i]);

            // APPROVE NECESSARY TOKENS ON MANGROVE
            TransferLib.approveToken(
                IERC20(pairs[i][0]),
                address(mgv),
                type(uint).max
            );
            TransferLib.approveToken(
                IERC20(pairs[i][1]),
                address(mgv),
                type(uint).max
            );

            // ******* GETTING THE DENSITY **************
            // (, MgvStructs.LocalPacked cfg) = mgv.config(pairs[i][1], pairs[i][0]);
            //   uint density = cfg.density();
            //   console.log(density);

            (uint offerId, ) = _newOffer(
                OfferArgs({
                    outbound_tkn: IERC20(pairs[i][0]),
                    inbound_tkn: IERC20(pairs[i][1]),
                    wants: volume[i],
                    gives: amounts[amounts.length - 1] - 5e18,
                    gasreq: 1000000,
                    gasprice: 0,
                    pivotId: 0, // a best pivot estimate for cheap offer insertion in the offer list - this should be a parameter computed off-chain for cheaper insertion
                    fund: 100000000000000000, // WEIs in that are used to provision the offer.
                    noRevert: false // we want to revert on error
                })
            );
            offerLists[i].push(offerId);
            console.log("OfferID:", offerId);
            // (uint offerId2, ) = _newOffer(
            //     OfferArgs({
            //         outbound_tkn: IERC20(pairs[i][1]), // what the offer should send to the taker
            //         inbound_tkn: IERC20(pairs[i][0]), //what the offer will receive from the taker
            //         wants: volume[i], //amount of inbound tokens requested by the offer
            //         gives: amounts2[0], //amount of outbound tokens promised by the offer
            //         gasreq: 100000,
            //         gasprice: 0,
            //         pivotId: 0, // a best pivot estimate for cheap offer insertion in the offer list - this should be a parameter computed off-chain for cheaper insertion
            //         fund: 100000000000000000, // WEIs in that are used to provision the offer.
            //         noRevert: false // we want to revert on error
            //     })
            // );
            // offerLists[i].push(offerId2);
            // console.log("OfferID2:", offerId2);
        }
    }

    function __lastLook__(
        MgvLib.SingleOrder calldata order
    ) internal override returns (bytes32 data) {
        data = super.__lastLook__(order);
        require(order.wants == order.offer.gives(), "MyOffer/mustBeFullyTaken");
    }

    // Simple implementation of the mangroveExecute function that is called by Mangrove to process the offer trade made by the maker
    function makerExecute(
        MgvLib.SingleOrder calldata order
    )
        external
        override(IMaker, MangroveOffer)
        onlyCaller(address(MGV))
        returns (bytes32 data)
    {
        // Invoke hook that implements a last look check during execution - it may renege on trade by reverting.
        data = __lastLook__(order);
        // check if the current contract actually got the tokens from the taker
        require(
            IERC20(order.inbound_tkn).balanceOf(address(this)) >= order.gives,
            "MyOffer/GotInsufficientFunds"
        );

        // Check if the current price is still profitable

        address pairAddress = IUniswapV2Factory(otherDexFactory).getPair(
            order.inbound_tkn,
            order.outbound_tkn
        );
        console.log(pairAddress);
        require(pairAddress != address(0), "PAIR_NOT_FOUND");


        (
            address[]  memory path,
            uint estimatedAmountOut
        ) = getPriceOut(order.inbound_tkn,order.outbound_tkn,pairAddress,order.gives);

        require(estimatedAmountOut >= order.wants, "Not profitable");
        // bounty=min⁡(offer.provision,(gas_used+local.offer_gasbase)×global.gasprice×109)
        // renege: estimatedOut - order.wants >= -tenacity*bounty (calculate avg gasUsed)

        // Actually EXECUTE the swap

        IERC20(order.inbound_tkn).approve(otherDexRouter, order.gives);
        IUniswapV2Router02(otherDexRouter)
            .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                order.gives,
                order.wants,
                path,
                address(this),
                block.timestamp
            );

        // check if the current contract now has enough tokens to give to the maker
        require(
            IERC20(order.outbound_tkn).balanceOf(address(this)) >= order.wants,
            "MyOffer/NotEnoughFunds"
        );
    }

    function getPriceOut(
        address inToken,
        address outToken,
        address pairAddress,
        uint amountIn
    )
        internal
        view
        returns (
            address[] memory path,
            uint estimatedAmountOut
        )
    {
        path = new address[](2);
        path[0] = inToken;
        path[1] = outToken;
        address [] memory pairPath = new address[](1);
        pairPath[0] = pairAddress;
        uint[] memory fees = new uint[](1);
        fees[0] = otherDexFees;

        uint256[] memory amounts = UniswapV2Library.getAmountsOut(
            amountIn,
            path,
            pairPath,
            fees
        );
        estimatedAmountOut = amounts[amounts.length - 1];
    }

    ///@notice Post-hook that is invoked when the offer is taken successfully.
    ///@inheritdoc Direct
    function __posthookSuccess__(
        MgvLib.SingleOrder calldata order,
        bytes32
    ) internal virtual override returns (bytes32) {
        uint currentBalanceIn = IERC20(order.inbound_tkn).balanceOf(address(this));
        uint currentBalanceOut = IERC20(order.outbound_tkn).balanceOf(address(this));
        console.log("HERE YES IN",currentBalanceIn);
        console.log("HERE YES OUT",currentBalanceOut);
        console.log("ADMIN",_admin);
        return 0;
    }

    function __posthookFallback__(
        MgvLib.SingleOrder calldata order,
        MgvLib.OrderResult calldata result
    ) internal virtual override returns (bytes32 data) {
        console.log("HERE NO");
        return 0;
    }

    // ///@inheritdoc ILiquidityProvider
    function newOffer(
        IERC20 outbound_tkn,
        IERC20 inbound_tkn,
        uint wants,
        uint gives,
        uint pivotId,
        uint gasreq /* the function is payable to allow us to provision an offer*/
    )
        public
        payable
        onlyAdmin /* only the admin of this contract is allowed to post offers using this contract*/
        returns (uint offerId)
    {
        (offerId, ) = _newOffer(
            OfferArgs({
                outbound_tkn: outbound_tkn,
                inbound_tkn: inbound_tkn,
                wants: wants,
                gives: gives,
                gasreq: gasreq,
                gasprice: 0,
                pivotId: pivotId, // a best pivot estimate for cheap offer insertion in the offer list - this should be a parameter computed off-chain for cheaper insertion
                // fund: msg.value, // WEIs in that are used to provision the offer.
                fund: msg.value, // WEIs in that are used to provision the offer.
                noRevert: false // we want to revert on error
            })
        );
    }

    ///@inheritdoc ILiquidityProvider
    function updateOffer(
        IERC20 outbound_tkn,
        IERC20 inbound_tkn,
        uint wants,
        uint gives,
        uint pivotId,
        uint offerId,
        uint gasreq
    ) public payable override adminOrCaller(address(MGV)) {
        _updateOffer(
            OfferArgs({
                outbound_tkn: outbound_tkn,
                inbound_tkn: inbound_tkn,
                wants: wants,
                gives: gives,
                gasreq: gasreq,
                gasprice: 0,
                pivotId: pivotId,
                fund: msg.value,
                noRevert: false
            }),
            offerId
        );
    }

    ///@inheritdoc ILiquidityProvider
    function retractOffer(
        IERC20 outbound_tkn,
        IERC20 inbound_tkn,
        uint offerId,
        bool deprovision
    ) public adminOrCaller(address(MGV)) returns (uint freeWei) {
        return _retractOffer(outbound_tkn, inbound_tkn, offerId, deprovision);
    }

    // function withdraw(uint _amount, address _token, bool isMATIC) public onlyAdmin{
    //     // If isMATIC (any _token address passed would be valid)
    // if(isMATIC){
    //     _amount = _amount>0? _amount: address(this).balance;
    //     (bool success, ) = payable(msg.sender).call{value: _amount}("");

    //     // bool success = payable(msg.sender).send(_amount);
    //     require(success,"Withdraw failed");
    // }else{
    //     _amount = _amount>0? _amount : IERC20(_token).balanceOf(address(this));
    //     IERC20(_token).transfer(msg.sender, _amount);
    // }

    // }
}
