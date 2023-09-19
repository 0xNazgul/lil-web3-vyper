// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

interface ILilFractional {
    event VaultCreated(
        uint256 indexed vaultId,
        address nftContract,
        uint256 tokenId,
        uint256 indexed tokenSupply,
        address tokenContract
    );
    event VaultDestroyed(
        uint256 indexed vaultId,
        address nftContract,
        uint256 tokenId,
        uint256 indexed tokenSupply,
        address tokenContract
    );

    function getVault(uint256 arg0) external view returns (address, uint256, uint256, address);
    function join(uint256 vault_id) external payable;
    function masterCopy() external view returns (address);
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes memory _data)
        external
        returns (bytes4);
    function split(
        address nft_contract,
        uint256 token_id,
        uint256 mint_supply,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) external payable returns (uint256);
    function vaultId() external view returns (uint256);
}
