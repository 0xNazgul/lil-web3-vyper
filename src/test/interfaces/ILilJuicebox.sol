// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

interface ILilJuicebox {
    event Contributed(address indexed contributor, uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);
    event Renounced(address sender);
    event StateUpdated(uint256 state);
    event Withdrawn(uint256 amount);

    function TOKENS_PER_ETH() external view returns (uint256);
    function contribute() external payable;
    function getState() external view returns (uint256);
    function manager() external view returns (address);
    function refund(uint256 amount) external payable;
    function renounce() external payable;
    function setState(uint256 state) external payable;
    function token() external view returns (address);
    function withdraw() external payable;
}
