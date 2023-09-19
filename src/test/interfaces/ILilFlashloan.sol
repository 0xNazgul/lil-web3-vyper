// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

interface ILilFlashloan {
    event FeeUpdated(address indexed token, uint256 fee);
    event Flashloaned(address indexed receiver, address indexed token, uint256 amount);
    event Withdrawn(address indexed token, uint256 amount);

    function execute(address receiver, address token, uint256 amount, bytes32 data) external payable;
    function fees(address arg0) external view returns (uint256);
    function getFees(address token, uint256 amount) external view returns (uint256);
    function manager() external view returns (address);
    function setFees(address token, uint256 fee) external payable;
    function withdraw(address token, uint256 amount) external payable;
}
