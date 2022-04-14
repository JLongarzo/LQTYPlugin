pragma solidity 0.8.10;



import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "../LqtyERC4626.sol";
import "../Interfaces/CErc20Interface.sol";

import "../interfaces/ComptrollerInterface.sol"; // am I trolling just turning this shit in compound codebase into an interface?

import "../interfaces/MasterPriceOracleInterface.sol";
import "../interfaces/ChainlinkPriceFeedInterface.sol";

//import "../Fuse-Flywheel.sol";
//import "../FuseFlywheelRewardsPlugin.sol";

//import "./console.sol";


import "ds-test/test.sol";
import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";




contract DeploymentTest is DSTestPlus {


    using stdStorage for StdStorage;
    StdStorage stdstore;

    struct RewardsState {
        /// @notice The strategy's last updated index
        uint224 index;
        /// @notice The timestamp the index was last updated at
        uint32 lastUpdatedTimestamp;
    }

    enum Error {
        NO_ERROR,
        UNAUTHORIZED,
        COMPTROLLER_MISMATCH,
        INSUFFICIENT_SHORTFALL,
        INSUFFICIENT_LIQUIDITY,
        INVALID_CLOSE_FACTOR,
        INVALID_COLLATERAL_FACTOR,
        INVALID_LIQUIDATION_INCENTIVE,
        MARKET_NOT_ENTERED, // no longer possible
        MARKET_NOT_LISTED,
        MARKET_ALREADY_LISTED,
        MATH_ERROR,
        NONZERO_BORROW_BALANCE,
        PRICE_ERROR,
        REJECTION,
        SNAPSHOT_ERROR,
        TOO_MANY_ASSETS,
        TOO_MUCH_REPAY
    }

    address user1 = address(0x123456);
    address user2 = address(0xabcdef);


    ComptrollerInterface cTroller = ComptrollerInterface(0xA9Ea472ad9Ef9339202e789c69BD2bE98436046e);

    MasterPriceOracleInterface MPO = MasterPriceOracleInterface(0x1887118E49e0F4A78Bd71B792a49dE03504A764D);
    address lqty = 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D;
    CErc20 c20;
    ChainlinkPriceOracleV2 clPriceFeed = ChainlinkPriceOracleV2(0xb0602af43Ca042550ca9DA3c33bA3aC375d20Df4);


    address lqtyMarket;

    event Number(uint256);
    event Addy(address);
    event Num2(uint224);


    /* LQTY plugin stuff */
    LqtyERC4626 private lqtyPlugin;
    ILQTYStaking private lqtyStaking = ILQTYStaking(0x4f9Fbb3f1E99B56e0Fe2892e623Ed36A76Fc605d);
    ERC20 public constant LUSD = ERC20(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);

    address constant rewardsOwner = address(0xDEE5);

    ERC20 LQTY = ERC20(0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D);
    
    CErc20Delegate c20DelegateLqty;

    FuseFlywheelCore lusdFlywheel;
    FuseFlywheelDynamicRewards lusdFlywheelRewardsModule;


    FuseFlywheelCore WETHFlywheel;
    FuseFlywheelDynamicRewards WETHFlywheelRewardsModule;
    ERC20 public constant WETH = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);


//0x67Db14E73C2Dce786B5bbBfa4D010dEab4BBFCF9 --default CErc20 implementation
//0xa731585ab05fC9f83555cf9Bff8F58ee94e18F85 --fuseadmin

    function setUp() public {

        //deploy the LQTY CToken market
        deployMarket();
       
        //deploy LqtyPugin
        deployPluginUpgradeCToken();

        //configure the LUSD flywheel and flywheel rewards module
        configLUSDFlywheel();

        //configure the WETH flywheel and flywheel rewards module
        configWETHFlywheel();

        //give lqty to addys
        writeTokenBalance(address(this), 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D, 1000000 * 1e18);
        writeTokenBalance(user1, 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D, 1000000 * 1e18);
        writeTokenBalance(user2, 0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D, 1000000 * 1e18);

        
    }

    /* setup functions */
    function deployMarket() internal {
        bytes memory constructorData = abi.encode(
            lqty, //lqty address
            0xA9Ea472ad9Ef9339202e789c69BD2bE98436046e, 
            0x14ee0270C80bEd60bDC117d4F218DeE0A4909F28, //interest rate model
            "LQTY",
            "LQTY",
            0x67Db14E73C2Dce786B5bbBfa4D010dEab4BBFCF9, //implementation
            new bytes(0),//0x00, 
            0, 
            0
        );

        address[] memory lq = new address[](1);
        lq[0] = lqty;

        AggregatorV3Interface[] memory agv3 = new AggregatorV3Interface[](1);
        agv3[0] = AggregatorV3Interface(0x84a24deCA415Acc0c395872a9e6a63E27D6225c8);


        PriceOracle[] memory orcl =  new PriceOracle[](1);
        orcl[0] = PriceOracle(0xb0602af43Ca042550ca9DA3c33bA3aC375d20Df4);


        //configure price feed in chainlink contract that is list of price feeds: 0xb0602af43Ca042550ca9DA3c33bA3aC375d20Df4
        hevm.prank(0x5eA4A9a7592683bF0Bc187d6Da706c6c4770976F);
        clPriceFeed.setPriceFeeds(lq, agv3 , FeedBaseCurrency.ETH);



        //impersonate admin and add oracle to mpo
        hevm.prank(0x5eA4A9a7592683bF0Bc187d6Da706c6c4770976F);
        MPO.add(lq, orcl); //addy is correct, the oracle is some random

        //require(cTroller._deployMarket(false, constructorData, .8e18) == Error.NO_ERROR);
        hevm.prank(0xa731585ab05fC9f83555cf9Bff8F58ee94e18F85);
        cTroller._deployMarket(false, constructorData, .8e18);       


        address[] memory allMarkets = cTroller.getAllMarkets();
        lqtyMarket = allMarkets[5];
    }

    function deployPluginUpgradeCToken() internal {
        lqtyPlugin = new LqtyERC4626(
            LQTY, 
            "LQTY", 
            "LQTY", 
            rewardsOwner,
            ILQTYStaking(0x4f9Fbb3f1E99B56e0Fe2892e623Ed36A76Fc605d)
        );


        //upgrade implementation to CErc20PluginDelegate and config the plugin
        c20DelegateLqty = CErc20Delegate(lqtyMarket);

        bytes memory becomeImplementationData = abi.encode(
            address(lqtyPlugin)
        );

        hevm.prank(0xa731585ab05fC9f83555cf9Bff8F58ee94e18F85);
        c20DelegateLqty._setImplementationSafe(0xf1F394AFe6744561788355C0cf3d0950B52F389d, false, becomeImplementationData );
    }

   function configLUSDFlywheel() internal {
        lusdFlywheel = new FuseFlywheelCore(
            LUSD,
            IFlywheelRewards(address(0)), //rewards module
            IFlywheelBooster(address(0)), //booster module
            address(this), //owner
            Authority(address(0)) //auth
        );

        lusdFlywheelRewardsModule = new FuseFlywheelDynamicRewards(
            LUSD,
            lusdFlywheel
        );

        lusdFlywheel.setFlywheelRewards(lusdFlywheelRewardsModule);

        //hook up module to flywheel
        //lusdFlywheel.setFlywheelRewards(lusdRewardsModule);

        //hook up to comptroller
        cTroller._addRewardsDistributor(address(lusdFlywheel));

        //set rewards destintion to flywheel
        hevm.prank(rewardsOwner);
        //lqtyPlugin.setRewardDestination(address(lqtyMarket)); //set to ctoken --dont do this do in constructor
        lqtyPlugin.setRewardDestination(address(lqtyMarket));

        hevm.prank(0xa731585ab05fC9f83555cf9Bff8F58ee94e18F85);
        CErc20PluginRewardsDelegate(lqtyMarket).approve(address(LUSD), address(lusdFlywheelRewardsModule));

        lusdFlywheel.addStrategyForRewards(ERC20(lqtyMarket));
   }

   function configWETHFlywheel() internal {
       WETHFlywheel = new FuseFlywheelCore(
            WETH,
            IFlywheelRewards(address(12239855972123529289)), //rewards module
            IFlywheelBooster(address(0)), //booster module
            address(this), //owner
            Authority(address(0)) //auth
       );
       
       WETHFlywheelRewardsModule = new FuseFlywheelDynamicRewards(
            WETH,
            WETHFlywheel
        );

        //console.log("before setFlywheelRewards");
        WETHFlywheel.setFlywheelRewards(WETHFlywheelRewardsModule);

        //console.log("before adding to comptroller");
        //hevm.prank(0xa731585ab05fC9f83555cf9Bff8F58ee94e18F85); - nah this dont fix
        cTroller._addRewardsDistributor(address(WETHFlywheel));

        //lqtyPlugin.setRewardDestination(address(lqtyMarket)); - this needs to be configd in a constructor
        //console.log("comptroller hooked up");


        hevm.prank(0xa731585ab05fC9f83555cf9Bff8F58ee94e18F85);
        CErc20PluginRewardsDelegate(lqtyMarket).approve(address(WETH), address(WETHFlywheelRewardsModule));

        //console.log("after hooked up");


        WETHFlywheel.addStrategyForRewards(ERC20(lqtyMarket));


   }




    /* utility functions */

    function writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore
            .target(token)
            .sig(IERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }




    /*test cases*/


    function testCtokenUnderlying () public {
        //CErc20 lqtyCToken = CErc20(lqtyMarket);
        //emit Addy(lqtyCToken.underlying());
        assertEq(0x6DEA81C8171D0bA574754EF6F8b412F2Ed88c54D, c20DelegateLqty.underlying());
    }

    function testUpgradeToPlugin() public {
        assertEq(c20DelegateLqty.plugin(), address(lqtyPlugin));
    }

    //redeemUnderlying() does not work... I dont think but redeem() does
    function testMintRedeem() public {
        //approve ctoken to spend lusd
        LQTY.approve(address(c20DelegateLqty), type(uint256).max);
        c20DelegateLqty.mint(10 * 1e18);
        


        //getCashPrior() is overriden by plugin and c20Delegate
        //emit Addy(address(lqtyPlugin));

        //emit Number(c20DelegateLqty.balanceOf(address(this)));
        

        //uint256 exRate = c20DelegateLqty.exchangeRateStored(); 
        //emit Number(exRate);

        c20DelegateLqty.redeemUnderlying(5*1e18); 
        c20DelegateLqty.redeem(10*1e18);

        //emit Number(c20DelegateLqty.balanceOf(address(this)));


        assertEq(c20DelegateLqty.balanceOf(address(this)), 15*1e18);

    }

    function testMintRedeemMultipleAddy() public {
        hevm.prank(user1);
        LQTY.approve(address(c20DelegateLqty), type(uint256).max);

        hevm.prank(user2);
        LQTY.approve(address(c20DelegateLqty), type(uint256).max);


        hevm.prank(user1);
        c20DelegateLqty.mint(10 * 1e18);

        hevm.prank(user2);
        c20DelegateLqty.mint(30 * 1e18);


        //emit Number(c20DelegateLqty.balanceOf(user1));
        //emit Number(c20DelegateLqty.balanceOf(user2));
        

        hevm.prank(user1);
        c20DelegateLqty.redeemUnderlying(10*1e18);
        //emit Number(c20DelegateLqty.balanceOf(user1));
        
        hevm.prank(user2);
        c20DelegateLqty.redeemUnderlying(15* 1e18);

        //emit Number(c20DelegateLqty.balanceOf(user2));

        assertEq(c20DelegateLqty.balanceOf(user1), 0);
        assertEq(c20DelegateLqty.balanceOf(user2), 75*1e18);

    }

    
    //simple test that only works for one user bc it compares a user's claim to total plugin amount
    //interesting 10 lusd is lost in the accrue accounting
    function testDepositCTokenAccrueLusdRewardsOneUser() external {

        hevm.prank(user1);
        LQTY.approve(address(c20DelegateLqty), type(uint256).max);
        hevm.prank(user1);
        c20DelegateLqty.mint(10 * 1e18);



        hevm.prank(0x24179CD81c9e782A4096035f7eC97fB8B783e007); //prank borrow ops contract
        lqtyStaking.increaseF_LUSD(30 * 1e18);
        
        //hevm.prank(0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2);
        //lqtyStaking.increaseF_ETH(29 * 1e18);


        //uint256 pluginPendingLusdRewards = lqtyStaking.getPendingLUSDGain(address(lqtyPlugin));
        //console.log("rewards pending in plugin: ", pluginPendingLusdRewards);


        lusdFlywheel.accrue(ERC20(lqtyMarket), user1);

        uint256 user1RewardsAccrued = lusdFlywheel.rewardsAccrued(user1);

        lusdFlywheel.claimRewards(user1);
       
        //console.log("user1 lusd balance: ", LUSD.balanceOf(user1));
        //console.log("dynamic rewards lusd balance: ", LUSD.balanceOf(address(lusdFlywheelRewardsModule)));
        assertEq(user1RewardsAccrued, LUSD.balanceOf(user1));

    }

    //once again the last 2 digits are rounded off
    //this probably not the most sound way to test but it works
    function testDepositCTokenAccrueLusdRewardsMultipleUsers() external {
        hevm.prank(user1);
        LQTY.approve(address(c20DelegateLqty), type(uint256).max);
        hevm.prank(user1);
        c20DelegateLqty.mint(10 * 1e18);

        hevm.prank(user2);
        LQTY.approve(address(c20DelegateLqty), type(uint256).max);
        hevm.prank(user2);
        c20DelegateLqty.mint(20 * 1e18);

        hevm.prank(0x24179CD81c9e782A4096035f7eC97fB8B783e007); //prank borrow ops contract
        lqtyStaking.increaseF_LUSD(30 * 1e18);

        console.log("pending rewards in lqtyStaking: ", lqtyStaking.getPendingLUSDGain(address(lqtyPlugin)));

        lusdFlywheel.accrue(ERC20(lqtyMarket), user1, user2);

        uint256 user1RewardsAccrued = lusdFlywheel.rewardsAccrued(user1);
        uint256 user2RewardsAccrued = lusdFlywheel.rewardsAccrued(user2);

        console.log("user1RewardsAccrued: ", user1RewardsAccrued);
        console.log("user2RewardsAccrued: ", user2RewardsAccrued);

        lusdFlywheel.claimRewards(user1);
        lusdFlywheel.claimRewards(user2);

        console.log("user1 lusd balance: ", LUSD.balanceOf(user1));
        console.log("user2 lusd balance: ", LUSD.balanceOf(user2));
        console.log("dynamic rewards lusd balance: ", LUSD.balanceOf(address(lusdFlywheelRewardsModule)));

        assertEq(LUSD.balanceOf(user2), LUSD.balanceOf(user1)*2); //this may not actually be sound given the last 2 digits that is lost

    }

    function testDepositCTokenAccrueWETHRewardsOneUser() external {
        hevm.prank(user1);
        LQTY.approve(address(c20DelegateLqty), type(uint256).max);
        hevm.prank(user1);
        c20DelegateLqty.mint(10 * 1e18);


        hevm.prank(0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2); //prank Trove Manager
        lqtyStaking.increaseF_ETH(30 * 1e18);

        WETHFlywheel.accrue(ERC20(lqtyMarket), user1);

        uint256 user1RewardsAccrued = WETHFlywheel.rewardsAccrued(user1);
        //console.log("user1RewardsAccrued: ", user1RewardsAccrued);

        WETHFlywheel.claimRewards(user1);

        //console.log("user1 WETH balance: ", WETH.balanceOf(user1));
        //console.log("dynamic rewards WETH balance: ", WETH.balanceOf(address(WETHFlywheelRewardsModule)));

        assertEq(user1RewardsAccrued, WETH.balanceOf(user1));
    }

    function testDepositCTokenAccrueWETHRewardsMultipleUsers() external {
        hevm.prank(user1);
        LQTY.approve(address(c20DelegateLqty), type(uint256).max);
        hevm.prank(user1);
        c20DelegateLqty.mint(10 * 1e18);

        hevm.prank(user2);
        LQTY.approve(address(c20DelegateLqty), type(uint256).max);
        hevm.prank(user2);
        c20DelegateLqty.mint(20 * 1e18);

        hevm.prank(0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2); //prank Trove Manager
        lqtyStaking.increaseF_ETH(30 * 1e18);

        WETHFlywheel.accrue(ERC20(lqtyMarket), user1, user2);

        //uint256 user1RewardsAccrued = WETHFlywheel.rewardsAccrued(user1);
        //uint256 user2RewardsAccrued = WETHFlywheel.rewardsAccrued(user2);

        //console.log("user1RewardsAccrued: ", user1RewardsAccrued);
        //console.log("user2RewardsAccrued: ", user2RewardsAccrued);

        WETHFlywheel.claimRewards(user1);
        WETHFlywheel.claimRewards(user2);

        //console.log("user1 WETH balance: ", WETH.balanceOf(user1));
        //console.log("user2 WETH balance: ", LUSD.balanceOf(user2));
        //console.log("dynamic rewards WETH balance: ", WETH.balanceOf(address(lusdFlywheelRewardsModule)));

        assertEq(WETH.balanceOf(user2), WETH.balanceOf(user1)*2);//LUSD.balanceOf(user1)*2);

    }

}


