pragma solidity ^0.8.0;


import "./ComptrollerInterface.sol";

interface MasterPriceOracleInterface {

    function add(address[] calldata underlyings, PriceOracle[] calldata _oracles) external;
    function setDefaultOracle(PriceOracle newOracle) external;
    function changeAdmin(address newAdmin) external;
    function getUnderlyingPrice(CToken cToken) external  view returns (uint);
    function price(address underlying) external  view returns (uint);


}

interface PriceOracle {
    function price(address underlying) external  view returns (uint);
}



interface CToken {
  


    /*** User Interface ***/

    function transfer(address dst, uint amount) external returns (bool);
    function transferFrom(address src, address dst, uint amount) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function balanceOfUnderlying(address owner) external returns (uint);
    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);
    function borrowRatePerBlock() external view returns (uint);
    function supplyRatePerBlock() external view returns (uint);
    function totalBorrowsCurrent() external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
    function getCash() external view returns (uint);
    function seize(address liquidator, address borrower, uint seizeTokens) external returns (uint);


    /*** Admin Functions ***/

    function _setReserveFactor(uint newReserveFactorMantissa) external returns (uint);
    function _reduceReserves(uint reduceAmount) external returns (uint);
    //function _setInterestRateModel(InterestRateModel newInterestRateModel) public returns (uint);
}