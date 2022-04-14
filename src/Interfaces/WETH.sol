
pragma solidity 0.8.10;



interface WETHInterface {
    function tranferFrom(address from, address to, uint bal) external returns ( bool );
    function transfer(address to, uint bal) external returns (bool);
    function balanceOf ( address owner ) external view returns ( uint256 );
    function deposit() external payable;
}