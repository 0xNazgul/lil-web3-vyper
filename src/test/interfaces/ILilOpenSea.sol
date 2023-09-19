// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

interface ILilOpenSea {
    event ListingBought(
        address indexed creator,
        address indexed buyer,
        uint256 listingId,
        address tokenContract,
        uint256 tokenId,
        uint256 indexed askPrice
    );
    event ListingRemoved(
        address indexed creator,
        uint256 indexed listingId,
        address tokenContract,
        uint256 indexed tokenId,
        uint256 askPrice
    );
    event NewFee(uint256 indexed oldFee, uint256 indexed newFee);
    event NewListing(
        address indexed creator,
        uint256 indexed listingId,
        address tokenContract,
        uint256 tokenId,
        uint256 indexed askPrice
    );
    event NewOwner(address indexed oldOwner, address indexed newOwner);
    event WithdrawFees(uint256 indexed amount);

    function buyListing(uint256 listing_id) external payable;
    function cancelListing(uint256 listing_id) external payable;
    function fee() external view returns (uint256);
    function getListing(uint256 arg0) external view returns (address, uint256, address, uint256);
    function list(address token_contract, uint256 token_id, uint256 ask_price) external payable returns (uint256);
    function newFee(uint256 new_fee) external;
    function newOwner(address new_owner) external;
    function owner() external view returns (address);
    function saleCounter() external view returns (uint256);
    function withdrawFees(uint256 amount) external;
}
