# @version ^0.3.9
"""
@title lil fractional vyper
@custom:contract-name LilFractional
@license GNU Affero General Public License v3.0
@author 0xNazgul
@dev Simple implementation of Fractional
"""

# @notice INFTShare of NFTShare and the 
# functions this contracts requires
interface INFTShare:
    def setup(name_: String[25], symbol_: String[5], decimals_: uint8, mint_supply: uint256, mint_to: address): nonpayable
    def transferFrom(owner: address, to: address, amount: uint256) -> bool: nonpayable
    def burn_from(owner: address, amount: uint256): nonpayable

interface IERC721:
    def transferFrom(from_: address, to: address, amount: uint256): nonpayable
    def balanceOf(user:address) -> uint256: nonpayable

# @notice Parameters for vaults
# @param nftContract The address contract for the fractionalized token
# @param tokenId The ID of the fractionalized token
# @param tokenSupply The amount of issued ERC20 tokens for this vault
# @param tokenContract The address for the issued tokens
struct Vault:
    nftContract: address 
    tokenId: uint256 
    tokenSupply: uint256
    tokenContract: address

# @notice Emitted when a token is fractionalized
# @param vault The details of the created vault
event VaultCreated:
    vaultId: indexed(uint256)
    nftContract: address 
    tokenId: uint256 
    tokenSupply: indexed(uint256)
    tokenContract: address

# @notice Emitted when a token is recovered from a vault
# @param vault The details of the destroyed vault
event VaultDestroyed:
    vaultId: indexed(uint256)
    nftContract: address 
    tokenId: uint256 
    tokenSupply: indexed(uint256)
    tokenContract: address

# @notice Used as a counter for the next vault index.
# @dev Initialised at 1 because it makes the first transaction slightly cheaper.
vaultId: public(uint256)

# @notice The master copy of the NFTShare contract 
# used to deploy a new NFTShare
masterCopy: public(address)

# @notice An indexed list of vaults
getVault: public(HashMap[uint256, Vault]) 

@external
@payable
def __init__(master_copy: address): 
    """
    @notice initialization of state 
    @param master_copy The master copy of NFTShare 
    """        
    self.vaultId  = 1 
    self.masterCopy = master_copy

@external
@payable
def split(nft_contract: address, token_id: uint256, mint_supply: uint256, name_: String[25], symbol_: String[5], decimals_: uint8) -> uint256:
    """
    @notice Fractionalize an ERC721 token
    @param nftContract The ERC721 contract for the token you're fractionalizing
    @param tokenId The ID of the token you're fractionalizing
    @param mint_supply The amount of ERC20 tokens to issue for this token. These will be distributed to the caller
    @param name The name for the resultant ERC20 token
    @param symbol The symbol for the resultant ERC20 token
    @param decimals The decimals fort the resultant ERC20 token
    @return The ID of the created vault
    @dev Remember to call setApprovalForAll(<address of this contract>, true) on the ERC721's contract before calling this function
    """
    addr: address = create_forwarder_to(self.masterCopy)
    INFTShare(addr).setup(name_, symbol_, decimals_, mint_supply, msg.sender)  

    self.getVault[self.vaultId] = Vault({
        nftContract: nft_contract,
        tokenId: token_id, 
        tokenSupply: mint_supply,
        tokenContract: addr
    })

    log VaultCreated(
        self.vaultId, 
        nft_contract, 
        token_id, 
        mint_supply, 
        addr
    )

    vault_id: uint256 = self.vaultId
    self.vaultId = vault_id + 1

    IERC721(nft_contract).transferFrom(msg.sender, self, token_id)  

    return vault_id

@external
@payable
def join(vault_id: uint256):
    """
	@notice Recover a fractionalized ERC721 token
	@param vaultId The ID of the vault containing the token
	@dev Remember to call approve(<address of this contract>, <supply or greater>) on the ERC20's contract before calling this function    
    """
    vault: Vault = self.getVault[vault_id]

    assert vault.tokenContract != empty(address), "Vault Not Found"

    self.getVault[vault_id] = Vault({
        nftContract: empty(address),
        tokenId: empty(uint256), 
        tokenSupply: empty(uint256),
        tokenContract: empty(address)
    })    

    log VaultDestroyed(
        vault_id, 
        vault.nftContract, 
        vault.tokenId, 
        vault.tokenSupply, 
        vault.tokenContract
    )

    INFTShare(vault.tokenContract).burn_from(msg.sender, vault.tokenSupply)
    IERC721(vault.nftContract).transferFrom(self, msg.sender, vault.tokenId)

@external
def onERC721Received(_operator: address, _from: address, _tokenId: uint256, _data: Bytes[1024]) -> bytes4:
    """
    @notice Whenever a `_tokenId` token is transferred to
         this contract via `safeTransferFrom` by
         `_operator` from `_from`, this function is called.
    @notice It must return its function selector to
            confirm the token transfer. If any other value
            is returned or the interface is not implemented
            by the recipient, the transfer will be reverted.
    @param _operator The 20-byte address which called
           the `safeTransferFrom` function.
    @param _from The 20-byte address which previously
           owned the token.
    @param _tokenId The 32-byte identifier of the token.
    @param _data The maximum 1024-byte additional data
           with no specified format.
    @return bytes4 The 4-byte function selector of `onERC721Received`.
    """
    return 0x150b7a02