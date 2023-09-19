# @version ^0.3.9
"""
@title lil superfluid
@custom:contract-name LilSuperfluid
@license GNU Affero General Public License v3.0
@author 0xNazgul
@notice Simple implementation of superfluid
"""

interface IERC20:
    def transfer(to: address, amount: uint256): nonpayable
    def transferFrom(from_: address, to: address, amount: uint256): nonpayable
    def balanceOf(user:address) -> uint256: nonpayable

# @notice Emitted when creating a new steam
# @param stream The newly-created stream
event StreamCreated:
    stream: Stream

# @notice Emitted when increasing the accessible balance of a stream
# @param streamId The ID of the stream receiving the funds
# @param amount The ERC20 token balance that is being added
event StreamRefueled:
    stream_id: indexed(uint256)
    amount: uint256

# @notice Emitted when the receiver withdraws the received funds
# @param streamId The ID of the stream having its funds withdrawn
# @param amount The ERC20 token balance being withdrawn
event FundsWithdrawn:
    stream_id: indexed(uint256)
    amount: uint256

# @notice Emitted when the sender withdraws excess funds
# @param streamId The ID of the stream having its excess funds withdrawn
# @param amount The ERC20 token balance being withdrawn
event ExcessWithdrawn:
    stream_id: indexed(uint256)
    amount: uint256

# @notice Emitted when the configuration of a stream is updated
# @param streamId The ID of the stream that was updated
# @param paymentPerBlock The new payment rate for this stream
# @param timeframe The new interval this stream will be active for
event StreamDetailsUpdated:
    stream_id: indexed(uint256)
    payment_per_block: uint256
    timeframe: Timeframe

# @dev Parameters for streams
# @param sender The address of the creator of the stream
# @param recipient The address that will receive the streamed tokens
# @param token The ERC20 token that is getting streamed
# @param balance The ERC20 balance locked in the contract for this stream
# @param withdrawnBalance The ERC20 balance the recipient has already withdrawn to their wallet
# @param paymentPerBlock The amount of tokens to stream for each new block
# @param timeframe The starting and ending block numbers for this stream
struct Stream:
    sender: address
    recipient: address
    token: address
    balance_: uint256
    withdrawn_balance: uint256
    payment_per_block: uint256
    timeframe: Timeframe

# @dev A block interval definition
# @param startBlock The first block where the token stream will be active
# @param stopBlock The last block where the token stream will be active
struct Timeframe:
    start_block: uint256
    stop_block: uint256

# @dev Components of an Ethereum signature
struct Signature:
    v: uint8
    r: bytes32
    s: bytes32

# @notice Used as a counter for the next stream index.
stream_id: public(uint256)

# @notice Signature nonce, incremented with each successful execution or state change
# @dev This is used to prevent signature reuse
nonce: public(uint256)

# @dev EIP-712 types for a signature that updates stream details
_UPDATE_DETAILS_HASH: public(constant(bytes32)) = keccak256("UpdateStreamDetails(uint256 streamId,uint256 paymentPerBlock,uint256 startBlock,uint256 stopBlock,uint256 nonce)")

# @dev The 32-byte type hash for the EIP-712 domain separator.
_TYPE_HASH: public(constant(bytes32)) = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")

# @dev Caches the domain separator as an `immutable`
# value, but also stores the corresponding chain ID
# to invalidate the cached domain separator if the
# chain ID changes.
_CACHED_DOMAIN_SEPARATOR: public(immutable(bytes32))
_CACHED_CHAIN_ID: public(immutable(uint256))

# @dev Caches `self` to `immutable` storage to avoid
# potential issues if a vanilla contract is used in
# a `delegatecall` context.
_CACHED_SELF: public(immutable(address))

# @dev `immutable` variables to store the (hashed)
# name and (hashed) version during contract creation.
_NAME: public(immutable(String[50]))
_HASHED_NAME: public(immutable(bytes32))
_VERSION: public(immutable(String[20]))
_HASHED_VERSION: public(immutable(bytes32))

# @notice An indexed list of streams
getStream: public(HashMap[uint256, Stream]) 

@external
@payable
def __init__(name_: String[50], version_: String[20]):
    """
    @notice initialization of state   
	@param name_ The name of the multisig
    @param version_ The version of the multisig
    """
    _NAME = name_
    _VERSION = version_
    _HASHED_NAME = keccak256(name_)
    _HASHED_VERSION = keccak256(version_)
    _CACHED_DOMAIN_SEPARATOR =  keccak256(_abi_encode(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION, chain.id, self))
    _CACHED_CHAIN_ID = chain.id
    _CACHED_SELF = self

    self.nonce = 1
    self.stream_id = 1

@external
@payable
def streamTo(recipient_: address, token_: address, initialBalance: uint256, timeframe_: Timeframe, paymentPerBlock_: uint256) -> uint256:
    """
	@notice Create a stream that continously delivers tokens to `recipient`
	@param recipient The address that will receive the streamed tokens
	@param token The ERC20 token that will get streamed
	@param initialBalance How many ERC20 tokens to lock on the contract. Note that only the locked amount is guaranteed to be delivered to `recipient`
	@param timeframe An interval of time, defined in block numbers, during which the stream will be active
	@param paymentPerBlock How many tokens to deliver for each block the stream is active
	@return The ID of the created stream
	@dev Remember to call approve(<address of this contract>, <initialBalance or greater>) on the ERC20's contract before calling this function    
    """
    self.getStream[self.stream_id] = Stream({
        sender: msg.sender, 
        recipient: recipient_,
        token: token_,
        balance_: initialBalance,
        withdrawn_balance: 0,
        payment_per_block: paymentPerBlock_,
        timeframe: timeframe_

    })  
    log StreamCreated(self.getStream[self.stream_id])

    stream_id_: uint256 = self.stream_id + 1
    self.stream_id = stream_id_    

    IERC20(token_).transferFrom(msg.sender, self, initialBalance)

    return stream_id_ - 1

@external 
@payable
def refuel(streamId: uint256, amount: uint256):
    """
	@notice Increase the amount of locked tokens for a certain token stream
	@param streamId The ID for the stream that you are locking the tokens for
	@param amount The amount of tokens to lock
	@dev Remember to call approve(<address of this contract>, <amount or greater>) on the ERC20's contract before calling this function    
    """
    assert self.getStream[streamId].sender == msg.sender, "Unauthorized"
    
    self.getStream[streamId].balance_ += amount

    log StreamRefueled(streamId, amount)

    IERC20(self.getStream[streamId].token).transferFrom(msg.sender, self, amount)

@external
@payable 
def withdraw(streamId: uint256):
    """
	@notice Receive some of the streamed tokens, only available to the receiver of the stream
	@param streamId The ID for the stream you are withdrawing the tokens from    
    """
    assert self.getStream[streamId].recipient == msg.sender, "Unauthorized"

    _balance: uint256 = self.balanceOf(streamId, msg.sender)

    self.getStream[streamId].withdrawn_balance += _balance

    log FundsWithdrawn(streamId, _balance)

    IERC20(self.getStream[streamId].token).transfer(msg.sender, _balance)

@external
@payable 
def refund(streamId: uint256):
    """
	@notice Withdraw any excess in the locked balance, only available to the creator of the stream after it's no longer active
	@param streamId The ID for the stream you are receiving the excess for    
    """
    assert self.getStream[streamId].sender == msg.sender, "Unauthorized"
    assert self.getStream[streamId].timeframe.stop_block < block.number, "Stream Still Active"

    _balance: uint256 = self.balanceOf(streamId, msg.sender)

    self.getStream[streamId].balance_ -= _balance

    log ExcessWithdrawn(streamId, _balance)

    IERC20(self.getStream[streamId].token).transfer(msg.sender, _balance)

@internal
@view
def calculateBlockDelta(timeframe: Timeframe) -> uint256:
    """
	@dev A function used internally to calculate how many blocks the stream has been active for so far
	@param timeframe The time interval the stream is supposed to be active for
	@param delta The amount of blocks the stream has been active for so far    
    """
    if(block.number <= timeframe.start_block):
         return 0
    if(block.number < timeframe.stop_block):
        return block.number - timeframe.start_block
    
    return timeframe.stop_block - timeframe.start_block

@external
@view
def getBalanceOf(streamId: uint256, who: address) -> uint256:
    """
    @notice a public version balanceOf
    """
    return self.balanceOf(streamId, who)

@internal
@view
def balanceOf(streamId: uint256, who: address) -> uint256:
    """
	@notice Check the balance of any of the involved parties on a stream
	@param streamId The ID of the stream you're looking up
	@param who The address of the party you want to know the balance of
	@return The ERC20 balance of the specified party
	@dev This function will always return 0 for any address not involved in the stream    
    """    
    assert self.getStream[streamId].sender != empty(address), "Stream Not Found"

    blockDelta: uint256 = self.calculateBlockDelta(self.getStream[streamId].timeframe)
    recipientBalance: uint256 = blockDelta * self.getStream[streamId].payment_per_block

    if (who == self.getStream[streamId].recipient):
        return recipientBalance - self.getStream[streamId].withdrawn_balance
    if (who == self.getStream[streamId].sender):
        return self.getStream[streamId].balance_ - recipientBalance

    return 0

@external
@payable
def updateDetails(streamId: uint256, paymentPerBlock: uint256, timeframe_: Timeframe, sig: Signature):
    """
	@notice Update the rate at which tokens get streamed, or the interval the stream is active for. Requires both parties to authorise the change
	@param streamId The ID for the stream which is getting its configuration updated
	@param paymentPerBlock The new rate at which tokens will get streamed
	@param timeframe The new interval, defined in blocks, the stream will be active for
	@param sig The signature of the other affected party for this change, certifying they approve of it    
    """
    assert self.getStream[streamId].sender != empty(address), "Stream Not Found"

    digest: bytes32 = keccak256(
        concat(
            b"\x19\x01",
            _CACHED_DOMAIN_SEPARATOR,
            keccak256(
                _abi_encode(
                    _UPDATE_DETAILS_HASH,
                    streamId,
                    paymentPerBlock,
                    timeframe_.start_block,
                    timeframe_.stop_block,
                    self.nonce
                )
            )
        )
    )
    self.nonce += self.nonce + 1
    sigAddress: address = ecrecover(digest, sig.v, sig.r, sig.s)

    if (
        not(self.getStream[streamId].sender == msg.sender and self.getStream[streamId].recipient == sigAddress) and
        not(self.getStream[streamId].sender == sigAddress and self.getStream[streamId].recipient == msg.sender)
    ):
        raise "Unauthorized"

    log StreamDetailsUpdated(streamId, paymentPerBlock, timeframe_)

    self.getStream[streamId].payment_per_block = paymentPerBlock
    self.getStream[streamId].timeframe = timeframe_

@external
@view
def buildUpdateStructHash(streamId: uint256, paymentPerBlock: uint256, timeframe_: Timeframe) -> bytes32:
    """
    """      
    return keccak256(
            _abi_encode(
                _UPDATE_DETAILS_HASH,
                streamId,
                paymentPerBlock,
                timeframe_.start_block,
                timeframe_.stop_block,
                self.nonce
            )
        )