// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

interface ILilENS {
    event NewNameFee(uint256 indexed oldFee, uint256 indexed newFee);
    event NewOwner(address indexed oldOwner, address indexed newOwner);
    event NewUpdateFee(uint256 indexed oldFee, uint256 indexed newFee);
    event Register(uint256 amount, uint256 amount_fee, string name, address indexed sender);
    event Update(uint256 amount, uint256 amount_fee, string name, address indexed newAddress, address indexed sender);
    event WithdrawFees(uint256 indexed amount);

    function lookup(string memory arg0) external view returns (address);
    function nameFee() external view returns (uint256);
    function newNameFee(uint256 new_fee) external;
    function newOwner(address new_owner) external;
    function newUpdateFee(uint256 new_fee) external;
    function owner() external view returns (address);
    function register(string memory name) external payable;
    function update(string memory name, address addr) external payable;
    function updateFee() external view returns (uint256);
    function withdrawFees() external;
}
