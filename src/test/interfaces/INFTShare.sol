// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

interface INFTShare {
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed owner, address indexed to, uint256 amount);

    function allowance(address arg0, address arg1) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address arg0) external view returns (uint256);
    function burn(uint256 amount) external;
    function burn_from(address owner, uint256 amount) external;
    function decimals() external view returns (uint8);
    function decrease_allowance(address spender, uint256 subtracted_amount) external returns (bool);
    function increase_allowance(address spender, uint256 added_amount) external returns (bool);
    function mint(address owner, uint256 amount) external;
    function name() external view returns (string memory);
    function setup(string memory name_, string memory symbol_, uint8 decimals_, uint256 mint_supply, address mint_to)
        external;
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address owner, address to, uint256 amount) external returns (bool);
}
