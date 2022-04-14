// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {SafeTransferLib, ERC20} from "solmate/utils/SafeTransferLib.sol";

import {IFlywheelRewards} from "flywheel-v2/interfaces/IFlywheelRewards.sol";
//import {FlywheelCore} from "flywheel-v2/FlywheelCore.sol";

//import "./test/console.sol";
import "./Fuse-Flywheel.sol";


interface ICERC20 {
    function plugin() external returns (address);
}

interface IERC4626 {
    function claimRewards() external;
}

/** 
 @title Fuse Flywheel Plugin Reward Stream
 @notice Determines rewards based on how many reward tokens appeared in the market itself since last accrual.
 All rewards are claimed atomically, so there is no need to use the last reward timestamp.
*/
contract FuseFlywheelDynamicRewards is IFlywheelRewards {
    using SafeTransferLib for ERC20;

    event Log(string message);

    /// @notice the reward token paid
    ERC20 public immutable override rewardToken;

    /// @notice the flywheel core contract
    FlywheelCore public immutable flywheel;

    constructor(ERC20 _rewardToken, FlywheelCore _flywheel) {
        rewardToken = _rewardToken;
        flywheel = _flywheel;
        _rewardToken.safeApprove(address(_flywheel), type(uint256).max);
    }

    /**
     @notice calculate and transfer accrued rewards to flywheel core
     @param market the market to accrue rewards for
     @return amount the amount of tokens accrued and transferred
     */
    function getAccruedRewards(ERC20 market, uint32)
        external
        override
        returns (uint256 amount)
    {
        require(msg.sender == address(flywheel), "!flywheel");
        IERC4626 plugin = IERC4626(ICERC20(address(market)).plugin());
       
        //console.log("amount in plugin before claim: ", rewardToken.balanceOf(address(plugin)));
        try plugin.claimRewards() {} catch {
            emit Log("!plugin.claimRewards()");
        }
        amount = rewardToken.balanceOf(address(market));

        //console.log("reward token addy: ", address(rewardToken));

        //console.log("plugin address dynamic rwards: ", address(plugin) );
        //console.log("lqtyMarket in dynamic rewards: ", address(market));
        //console.log("rewardsModule addy: ", address(this));
        //console.log("amount in market: ", amount);
        //console.log("amount in plugin after claim: ", rewardToken.balanceOf(address(plugin)));

        

        if (amount > 0)
            rewardToken.safeTransferFrom(
                address(market),
                address(flywheel.flywheelRewards()),
                amount
            );

        //console.log("amount in market after transfer", rewardToken.balanceOf(address(market)));
        //console.log("amount in dynamicrewards after transfer", rewardToken.balanceOf(address(this)));
    }
}