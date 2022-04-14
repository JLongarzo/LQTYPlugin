// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "../LqtyERC4626.sol";
//import "../Interfaces/ILQTYStaking.sol";


import "ds-test/test.sol";
import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";


import {ERC4626, ERC20} from "solmate/mixins/ERC4626.sol";



//tbh this test contract is unnecessary - just need deploy one

contract ContractTest is DSTestPlus {
    using stdStorage for StdStorage;
    StdStorage stdstore;

    LqtyERC4626 private lqtyPlugin;
    ILQTYStaking private lqtyStaking = ILQTYStaking(0x4f9Fbb3f1E99B56e0Fe2892e623Ed36A76Fc605d);
    ERC20 public constant LUSD = ERC20(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);

    address constant rewardsOwner = address(0xDEE5);

    ERC20 LQTY = ERC20(0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D);

    event Sup(address);
    event Number(uint256);


    WETHInterface public constant WETH = WETHInterface(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);


    function setUp() public {
        lqtyPlugin = new LqtyERC4626(
            LQTY, 
            "LQTY", 
            "LQTY", 
            rewardsOwner,
            ILQTYStaking(0x4f9Fbb3f1E99B56e0Fe2892e623Ed36A76Fc605d)
        );

        //give an address LQTY tokens with cheats
        writeTokenBalance(address(this), 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D, 1000000 * 1e18 );

    }

    function writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore
            .target(token)
            .sig(IERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }


   //test change setRewardDestination
    function testSetRewardsDestination() public {
        hevm.prank(rewardsOwner);
        lqtyPlugin.setRewardDestination(address(1));
        
        address newThing = lqtyPlugin.rewardDestination();

        assertEq(address(1), newThing);
    }

    //one that fails expects revert
    function testCannotSetRewardsDestination() public {
        hevm.prank(address(2));
        hevm.expectRevert("UNAUTHORIZED");
        lqtyPlugin.setRewardDestination(address(1));
    }




    //test deposit into the 4626 vault
    function testDeposit() public {
        LQTY.approve(address(lqtyPlugin), type(uint256).max); //should I just do this in setup idk
        lqtyPlugin.deposit(10 * 1e18, address(this));
        assertEq(10 * 1e18, lqtyPlugin.totalAssets()); 
    }


    //test withdraw
    function testDepositWithdrawAll() public {
        LQTY.approve(address(lqtyPlugin), type(uint256).max);
        lqtyPlugin.deposit(10 * 1e18, address(this));

        assertEq(10 * 1e18, lqtyPlugin.totalAssets());

        lqtyPlugin.withdraw(10 * 1e18, address(this), address(this));

         assertEq(0, lqtyPlugin.totalAssets());
    }


    function testDepositWithdrawl() public {
        LQTY.approve(address(lqtyPlugin), type(uint256).max);
        lqtyPlugin.deposit(10 * 1e18, address(this));
        lqtyPlugin.withdraw(5 * 1e18, address(this), address(this));
        assertEq(5 * 1e18, lqtyPlugin.totalAssets());
    }


    //https://github.com/brockelmore/forge-std - can use stdError.arithmeticError?
    function testFailDepositWithdrawTooMuch() public { //need to fix this one so it catches the right error
        LQTY.approve(address(lqtyPlugin), type(uint256).max);
        lqtyPlugin.deposit(10 * 1e18, address(this));
        //hevm.expectRevert("Arithmetic over/underflow");
        lqtyPlugin.withdraw(15 * 1e18, address(this), address(this));
        //hevm.expectRevert("LQTYStaking: User must have a non-zero stake");
        
    }

    //somehow test claim rewards

    //is this a stupid test?
    function testClaimNoDepositRewards() public {
        hevm.expectRevert("LQTYStaking: User must have a non-zero stake");
        lqtyPlugin.claimRewards();
    }

    function testClaimDepositZeroRewardsAccumulated() public {
        uint256 initialBal = address(this).balance;
        LQTY.approve(address(lqtyPlugin), type(uint256).max);
        lqtyPlugin.deposit(10 * 1e18, address(this));
        lqtyPlugin.claimRewards();

        uint256 currentBal = address(this).balance;
        
        assertEq(initialBal, currentBal);
        assertEq(0, LUSD.balanceOf(address(this)));
    }


    //need to figure out how to change the internal accounting of lqtyStaking

/*
    it is a mapping of Snapshots
 struct Snapshot {
        uint F_ETH_Snapshot;
        uint F_LUSD_Snapshot;
    }

//nah fuck changing the accounting
//impersonate TroveManager to send eth rewards
//impersonate BorrowerOperations to send LUSD



*/



    function testClaimSomeEthRewards() public {
        LQTY.approve(address(lqtyPlugin), type(uint256).max);
        lqtyPlugin.deposit(1000000 * 1e18, address(this));

        hevm.prank(0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2);
        lqtyStaking.increaseF_ETH(29 * 1e18);
       
        uint256 myPendingEthRewards = lqtyStaking.getPendingETHGain(address(lqtyPlugin));

        lqtyPlugin.claimRewards();

        assertEq(WETH.balanceOf(rewardsOwner), myPendingEthRewards);
    }

    //test totalAssets()
   function testTotalAssetsStartsAtZero() public {
       
       assertEq(0, lqtyPlugin.totalAssets());
   }


    receive() external payable {}
}
