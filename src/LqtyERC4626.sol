// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {ERC4626, ERC20} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import "./interfaces/ILQTYStaking.sol";
import "./interfaces/ILQTYToken.sol";

//import "./test/console.sol";
import "./FuseFlywheelRewardsPlugin.sol";
import "./Interfaces/WETH.sol";



contract LqtyERC4626 is ERC4626 {
    
    using SafeTransferLib for ERC20;
    //using SafeTransferLib for WETHInterface; //is this legit?

    event Sup(string);
    WETHInterface public constant WETH = WETHInterface(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);


    ERC20 public constant LUSD = ERC20(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0); //whats the benefit of using solmate ERC20 abstract contract vs an interface?
    address payable public rewardDestination; //flywheel - but how tf do I set this part up
    ILQTYStaking public immutable lqtyStaking; //why use immutable? - immutable allows it to be set in the constructor whereas const doesn't


    event RewardDestinationUpdate(address indexed newDestination);

    constructor(
        //4626 stuff
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        //set rewardsdestination
        address _rewardDestination,
        ILQTYStaking _lqtyStaking
    )   
        ERC4626(_asset, _name, _symbol) 
    {

        rewardDestination = payable(_rewardDestination); 
        lqtyStaking = _lqtyStaking; 

        //approve lqtystaking contract
        _asset.approve(address(_lqtyStaking), type(uint256).max);
    }


    function setRewardDestination(address newDestination) external {
        require(msg.sender == rewardDestination, "UNAUTHORIZED");
        rewardDestination = payable(newDestination);
        emit RewardDestinationUpdate(newDestination);
    }

 
    //get rewards from LQTYStaking - both eth and LUSD and send them to right location
    function claimRewards() external {

        //Unsake with amount set to zero just claims rewards
        lqtyStaking.unstake(0);
                
        console.log("ethBal: ", address(this).balance);

        WETH.deposit{value: address(this).balance}();
        uint256 bal = WETH.balanceOf(address(this));
        console.log("WETH in plugin after wrap ", bal);
        //WETH.safeTransfer(rewardDestination, WETH.balanceOf(address(this))); - this doesnt work idk why and idk what the point of safe transfer is
        WETH.transfer(rewardDestination, uint(WETH.balanceOf(address(this))));


        console.log("lusdBal: ", LUSD.balanceOf(address(this)));


        LUSD.safeTransfer(rewardDestination, LUSD.balanceOf(address(this)));

        
        console.log("lusd in plugin desination: ", LUSD.balanceOf(address(rewardDestination)));
        console.log("plugin rewards destination: ", rewardDestination);

    }


    //may have to transfer the staking rewards to flywheel?
    function afterDeposit(uint256 amount, uint256) internal override {
        lqtyStaking.stake(amount);
    }




    function beforeWithdraw(uint256 amount, uint256) internal override {
        lqtyStaking.unstake(amount);
    }





    /// @notice Calculates the total amount of underlying tokens the Vault holds.   
    /// @return The total amount of underlying tokens the Vault holds.
    function totalAssets() public view override returns (uint256) {
        return lqtyStaking.stakes(address(this));
    }

    function assetsOf(address user) public view virtual returns (uint256) {
        return previewRedeem(balanceOf[user]);
    }

    receive() external payable {}
}

