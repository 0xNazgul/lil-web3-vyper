# @version ^0.3.9
"""
@title lil opensea vyper
@custom:contract-name LilOpenSea
@license GNU Affero General Public License v3.0
@author 0xNazgul
@notice Simple implementation of OpenSea
"""

interface IERC721:
    def transferFrom(from_: address, to: address, amount: uint256): nonpayable
    def balanceOf(user:address) -> uint256: nonpayable

# @notice Stores the current owner
owner: public(address)

# @notice fee to create a listing 
fee: public(uint256)

# @notice Parameters for listings
# @param tokenContract the contract for the listed token
# @param tokenId The ID of the listed token
# @param creator The address of the seller
# @param askPrice The amount the seller is asking for in exchange for the token
struct Listing:
    tokenContract: address 
    tokenId: uint256 
    creator: address
    askPrice: uint256

# @notice Used as a counter for the next sale index.
# @dev Initialised at 1 because it makes the first transaction slightly cheaper.
saleCounter: public(uint256) 

# @notice An indexed list of listings
getListing: public(HashMap[uint256, Listing])

# @notice Emitted when owner is updated
# @param oldOwner The old owner
# @param newOwner The new owner
event NewOwner:
    oldOwner: indexed(address)
    newOwner: indexed(address)

# @notice Emitted when owner updates listing fee
# @param oldFee The old  listing fee
# @param newFee The new listing fee
event NewFee:
    oldFee: indexed(uint256)
    newFee: indexed(uint256)    

# @notice Emitted when a new listing is created
# @param listing The newly-created listing
event NewListing:
    creator: indexed(address)
    listingId: indexed(uint256)
    tokenContract: address
    tokenId: uint256 
    askPrice: indexed(uint256)

# @notice Emitted when a listing is cancelled
# @param listing The removed listing
event ListingRemoved:
    creator: indexed(address)
    listingId: indexed(uint256)
    tokenContract: address
    tokenId: indexed(uint256) 
    askPrice: uint256

# @notice Emitted when a listing is purchased
# @param buyer The address of the buyer
# @param listing The purchased listing
event ListingBought:
    creator: indexed(address)
    buyer: indexed(address)
    listingId: uint256
    tokenContract: address
    tokenId: uint256 
    askPrice: indexed(uint256)

# @notice Emitted when owner withdraws fees
# @param amount The amount the owner is withdrawing
event WithdrawFees:
    amount: indexed(uint256)    

@external
@payable
def __init__(init_fee: uint256):
    """
    @notice initialization of state
    @param init_fee The fee charged when listing
    """
    assert init_fee <= 1*10**18, "Fee too high"
    self.fee = init_fee
    self.owner = msg.sender    
    self.saleCounter = 1

@external
@payable
def list(token_contract: address, token_id: uint256, ask_price: uint256) -> uint256:
    """
	@notice List an ERC721 token for sale
	@param tokenContract The ERC721 contract for the token you're listing
	@param tokenId The ID of the token you're listing
	@param askPrice How much you want to receive in exchange for the token
	@return The ID of the created listing
	@dev Remember to call setApprovalForAll(<address of this contract>, true) on the ERC721's contract before calling this function    
    """
    self.getListing[self.saleCounter] = Listing({
        tokenContract: token_contract,
        tokenId: token_id,
        creator: msg.sender,
        askPrice: ask_price
    })

    assert msg.value >= self.fee, "Not enough for fee"
    
    log NewListing(msg.sender, self.saleCounter, token_contract, token_id, ask_price)

    sale_counter: uint256 = self.saleCounter
    self.saleCounter = sale_counter + 1
    IERC721(token_contract).transferFrom(msg.sender, self,  token_id)

    if msg.value - self.fee > 0:
        send(msg.sender, msg.value - self.fee)

    return sale_counter

@external
@payable
def cancelListing(listing_id: uint256):
    """
	@notice Cancel an existing listing
	@param listingId The ID for the listing you want to cancel    
    """
    l: Listing = self.getListing[listing_id]

    assert l.creator == msg.sender, "Unauthorized"

    log ListingRemoved(msg.sender, listing_id, l.tokenContract, l.tokenId, l.askPrice)

    self.getListing[listing_id] = Listing({
        tokenContract: empty(address),
        tokenId: empty(uint256),
        creator: empty(address),
        askPrice: empty(uint256)
    })
    IERC721(l.tokenContract).transferFrom(self, msg.sender,  l.tokenId)

@external
@payable
def buyListing(listing_id: uint256):
    """
	@notice Purchase one of the listed tokens
	@param listingId The ID for the listing you want to purchase    
    """
    l: Listing = self.getListing[listing_id]

    log ListingBought(l.creator, msg.sender, listing_id, l.tokenContract, l.tokenId, l.askPrice)

    assert l.creator != empty(address), "Listing Not Found"
    assert  msg.value >= l.askPrice, "Not enough value sent"

    self.getListing[listing_id] = Listing({
        tokenContract: empty(address),
        tokenId: empty(uint256),
        creator: empty(address),
        askPrice: empty(uint256)
    })    

    send(l.creator, l.askPrice)
    
    IERC721(l.tokenContract).transferFrom(self, msg.sender,  l.tokenId)
    
    if msg.value - l.askPrice > 0:
        send(msg.sender, msg.value - l.askPrice)

@external
def newOwner(new_owner: address):
    """
    @notice Allows the owner to change ownership
    @param new_owner The new owner of the contract
    """    
    assert msg.sender == self.owner, "Unauthorized"
    assert new_owner != empty(address), "Zero address not allowed"
    self.owner = new_owner
    log NewOwner(msg.sender, new_owner)

    
@external
def newFee(new_fee: uint256):
    """
    @notice Allows the owner to change the listing fee
    @param new_fee The new listing fee 
    """
    assert new_fee <= 1*10**18, "Fee too high"
    assert msg.sender == self.owner, "Unauthorized"
    log NewFee(self.fee, new_fee)
    self.fee = new_fee

@external
def withdrawFees(amount: uint256):
    """
    @notice Allows the owner to withdraw an amount of the fees from this contracts balance
    @param amount The amount the owner wants to withdraw
    """    
    assert msg.sender == self.owner, "Unauthorized"
    log WithdrawFees(amount)
    send(msg.sender, amount)    