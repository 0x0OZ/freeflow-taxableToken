//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface WETH9 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
    function approve(address guy, uint256 wad) external returns (bool);
    function transfer(address dst, uint256 wad) external returns (bool);
    function transferFrom(address src, address dst, uint256 wad) external returns (bool);
    function name() external returns (string memory);
    function symbol() external returns (string memory);
    function balanceOf(address owner) external view returns (uint256);
}
