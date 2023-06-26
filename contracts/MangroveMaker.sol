// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "hardhat/console.sol";

// import "./UniswapV2Library.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";

import {Direct} from "../node_modules/@mangrovedao/mangrove-core/src/strategies/offer_maker/abstract/Direct.sol";
import {ILiquidityProvider} from
    "../node_modules/@mangrovedao/mangrove-core/src/strategies/interfaces/ILiquidityProvider.sol";
import {TransferLib} from "../node_modules/@mangrovedao/mangrove-core/src/strategies/utils/TransferLib.sol";
import {MangroveOffer} from "../node_modules/@mangrovedao/mangrove-core/src/strategies/MangroveOffer.sol";
import {IMangrove} from "../node_modules/@mangrovedao/mangrove-core/src/IMangrove.sol";
import {IERC20, MgvLib, MgvStructs, IMaker} from "../node_modules/@mangrovedao/mangrove-core/src/MgvLib.sol";

/* GENERAL NOTES

- Volumes are represented by the 2nd token in each pair
- otherDex should be a fork of UNISWAP

- Example of a paid BOUNTY (0.00057235)

* SHOULD BE IMPLEMENT

- Check the balance of the PROVISION in Mangrove
- Implement the withdrawal of the provision from the Mangrove contract
- Check if the requested volume is available in the pair's reserves BEFORE estimation and swap
- Calculate if the losing funds on a swap is better than paying the renege bounty
    bounty=min⁡(offer.provision,(gas_used+local.offer_gasbase)×global.gasprice×109)
    renege: estimatedOut - order.wants >= -tenacity*bounty (calculate avg gasUsed)
- (optional) Function to check the density of a market
    (, MgvStructs.LocalPacked cfg) = mgv.config(pairs[i][1], pairs[i][0]);
    uint density = cfg.density();

*/

contract MangroveMaker is Direct, ILiquidityProvider {
    IMangrove mgv;
    uint256[] public spread;
    uint256[] public volume;
    uint256[] public tenacity;
    address[][] public pairs;
    address public otherDexFactory;
    address public otherDexRouter;
    uint256[][] public offerLists;

    constructor(
        IMangrove _mgv,
        uint256[] memory _spread,
        uint256[] memory _volume,
        uint256[] memory _tenacity,
        address[][] memory _pairs,
        address _otherDexFactory,
        address _otherDexRouter,
        address admin
    ) Direct(_mgv, NO_ROUTER, 100_000, admin) {
        mgv = _mgv;
        spread = _spread;
        volume = _volume;
        tenacity = _tenacity;
        pairs = _pairs;
        otherDexFactory = _otherDexFactory;
        otherDexRouter = _otherDexRouter;

        offerLists = new uint[][](pairs.length);
        for (uint256 i = 0; i < pairs.length; i++) {
            offerLists[i] = new uint[](0);
        }
    }

    function updateParams(
        uint256[] memory _spread,
        uint256[] memory _volume,
        uint256[] memory _tenacity,
        address[][] memory _pairs,
        address _otherDexFactory,
        address _otherDexRouter
    ) public onlyAdmin {
        spread = _spread;
        volume = _volume;
        tenacity = _tenacity;
        pairs = _pairs;
        otherDexFactory = _otherDexFactory;
        otherDexRouter = _otherDexRouter;

        offerLists = new uint[][](pairs.length);
        for (uint256 i = 0; i < pairs.length; i++) {
            offerLists[i] = new uint[](0);
        }
    }

    function getTrackedPairs() public view returns (address[][] memory) {
        return pairs;
    }

    function getOfferLists() public view returns (uint256[][] memory) {
        return offerLists;
    }

    function createInitialOffers() public payable onlyAdmin {
        for (uint256 i = 0; i < pairs.length; i++) {
            (OfferArgs memory askArgs, OfferArgs memory bidArgs) = generateOffers(i, false);

            // Approve the necessary tokens for Mangrove
            TransferLib.approveToken(IERC20(pairs[i][0]), address(mgv), type(uint256).max);
            TransferLib.approveToken(IERC20(pairs[i][1]), address(mgv), type(uint256).max);

            // ask offer

            (uint256 askOfferId,) = _newOffer(askArgs);
            offerLists[i].push(askOfferId);
            console.log("askOfferId:", askOfferId);

            // bid offer

            (uint256 bidOfferId,) = _newOffer(bidArgs);
            offerLists[i].push(bidOfferId);
            console.log("bidOfferId:", bidOfferId);
        }
    }

    function __lastLook__(MgvLib.SingleOrder calldata order) internal override returns (bytes32 data) {
        data = super.__lastLook__(order);
        // check if the order is fully taken or it's a partial fill
        require(order.wants == order.offer.gives(), "MyOffer/mustBeFullyTaken");

        // check if the current contract actually got the tokens from the taker
        require(IERC20(order.inbound_tkn).balanceOf(address(this)) >= order.gives, "MyOffer/GotInsufficientFunds");

        // check if the pair exists on the "other DEX"
        address pairAddress = IUniswapV2Factory(otherDexFactory).getPair(order.inbound_tkn, order.outbound_tkn);
        require(pairAddress != address(0), "PAIR_NOT_FOUND");

        // Check if the current price is still profitable
        (address[] memory path, uint256 estimatedAmountOut) =
            getRequiredVolume(order.inbound_tkn, order.outbound_tkn, order.gives, true);
        require(estimatedAmountOut >= order.wants, "Not profitable");

        // Actually EXECUTE the swap
        IERC20(order.inbound_tkn).approve(otherDexRouter, order.gives);
        IUniswapV2Router02(otherDexRouter).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            order.gives, order.wants, path, address(this), block.timestamp
        );

        // check if the current contract now has enough tokens to give to the maker
        require(IERC20(order.outbound_tkn).balanceOf(address(this)) >= order.wants, "MyOffer/NotEnoughFunds");
    }

    function generateOffers(uint256 pairIndex, bool isUpdate)
        internal
        view
        returns (OfferArgs memory askArgs, OfferArgs memory bidArgs)
    {
        // Check if token addresses are passed properly (not zero adresses)
        require(
            (address(pairs[pairIndex][0]) != address(0)) && (address(pairs[pairIndex][1]) != address(0)),
            "TOKEN ADDRESS IS ZERO"
        );
        // Check if the pair actually exists in the "otherDex"
        address pairAddress = IUniswapV2Factory(otherDexFactory).getPair(pairs[pairIndex][0], pairs[pairIndex][1]);
        require(pairAddress != address(0), "PAIR_NOT_FOUND");

        // calculate amount of token1 expected when selling ($volume) of token0
        (, uint256 estimatedAmountOut) =
            getRequiredVolume(pairs[pairIndex][1], pairs[pairIndex][0], volume[pairIndex], true);
        console.log(volume[pairIndex], "=>", estimatedAmountOut);

        (, uint256 estimatedAmountIn) =
            getRequiredVolume(pairs[pairIndex][0], pairs[pairIndex][1], volume[pairIndex], false);
        console.log(estimatedAmountIn, "=>", volume[pairIndex]);

        // ask offer
        askArgs = OfferArgs({
            outbound_tkn: IERC20(pairs[pairIndex][0]),
            inbound_tkn: IERC20(pairs[pairIndex][1]),
            wants: volume[pairIndex],
            // gives: estimatedAmountOut - ((estimatedAmountOut * spread[pairIndex]) / 100),
            gives: estimatedAmountOut
                - ((estimatedAmountOut * (isUpdate ? spread[pairIndex] : spread[pairIndex] - 1)) / 100),
            gasreq: 1000000,
            gasprice: 0,
            pivotId: 0,
            fund: 100000000000000000, // WEIs in that are used to provision the offer.
            noRevert: false // we want to revert on error
        });

        // bid offer

        bidArgs = OfferArgs({
            outbound_tkn: IERC20(pairs[pairIndex][1]), // what the offer should send to the taker
            inbound_tkn: IERC20(pairs[pairIndex][0]), //what the offer will receive from the taker
            // wants: estimatedAmountIn + ((estimatedAmountIn * spread[pairIndex]) / 100), //amount of inbound tokens requested by the offer
            wants: estimatedAmountIn + ((estimatedAmountIn * (isUpdate ? spread[pairIndex] : spread[pairIndex] - 1)) / 100), //amount of inbound tokens requested by the offer
            gives: volume[pairIndex], //amount of outbound tokens promised by the offer
            gasreq: 1000000,
            gasprice: 0,
            pivotId: 0, // a best pivot estimate for cheap offer insertion in the offer list - this should be a parameter computed off-chain for cheaper insertion
            fund: 100000000000000000, // WEIs in that are used to provision the offer.
            noRevert: false // we want to revert on error
        });
    }

    function getRequiredVolume(address inToken, address outToken, uint256 amount, bool isOut)
        internal
        view
        returns (address[] memory path, uint256 requiredVolume)
    {
        path = new address[](2);
        path[0] = inToken;
        path[1] = outToken;

        if (isOut) {
            uint256[] memory amounts = IUniswapV2Router02(otherDexRouter).getAmountsOut(amount, path);
            requiredVolume = amounts[amounts.length - 1];
        } else {
            uint256[] memory amounts = IUniswapV2Router02(otherDexRouter).getAmountsIn(amount, path);
            requiredVolume = amounts[0];
        }
    }

    ///@notice Post-hook that is invoked when the offer is taken successfully.
    ///@inheritdoc Direct
    function __posthookSuccess__(MgvLib.SingleOrder calldata order, bytes32)
        internal
        virtual
        override
        returns (bytes32)
    {
        updateOffers();
        return 0;
    }

    function __posthookFallback__(MgvLib.SingleOrder calldata order, MgvLib.OrderResult calldata result)
        internal
        virtual
        override
        returns (bytes32 data)
    {
        updateOffers();
        return 0;
    }

    function updateOffers() internal {
        for (uint256 i = 0; i < pairs.length; i++) {
            (OfferArgs memory askArgs, OfferArgs memory bidArgs) = generateOffers(i, true);
            // ask offer
            _updateOffer(askArgs, offerLists[i][0]);
            // bid offer
            _updateOffer(bidArgs, offerLists[i][1]);
        }
    }

    // ///@inheritdoc ILiquidityProvider
    function newOffer(
        IERC20 outbound_tkn,
        IERC20 inbound_tkn,
        uint256 wants,
        uint256 gives,
        uint256 pivotId,
        uint256 gasreq /* the function is payable to allow us to provision an offer*/
    )
        public
        payable
        onlyAdmin /* only the admin of this contract is allowed to post offers using this contract*/
        returns (uint256 offerId)
    {
        (offerId,) = _newOffer(
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
        uint256 wants,
        uint256 gives,
        uint256 pivotId,
        uint256 offerId,
        uint256 gasreq
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
    function retractOffer(IERC20 outbound_tkn, IERC20 inbound_tkn, uint256 offerId, bool deprovision)
        public
        adminOrCaller(address(MGV))
        returns (uint256 freeWei)
    {
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
