# @version ^0.3.9
"""
@title lil flashLoan vyper
@custom:contract-name LilFlashLoan
@license GNU Affero General Public License v3.0
@author 0xNazgul
@dev Simple implementation a flashloan
"""

interface IERC20:
    def transfer(to: address, amount: uint256): nonpayable
    def balanceOf(user:address) -> uint256: nonpayable

interface IFlashBorrower:
    def onFlashLoan(token: address, amount: uint256, data: bytes32): nonpayable

# @notice The manager of this contract
manager: public(immutable(address))

# @notice A list of the fee percentages (multiplied by 100 to avoid decimals, for example 10% is 10_00) for each token
fees: public(HashMap[address, uint256])

# @notice Emitted when the fees for flash loaning a token have been updated
# @param token The ERC20 token to apply the specified fee to
# @param fee The new fee for this token as a percentage and multiplied by 100 to avoid decimals (for example, 10% is 10_00)
event FeeUpdated:
    token: indexed(address)
    fee: uint256

# @notice Emitted when the manager withdraws part of the contract's liquidity
# @param token The ERC20 token that was withdrawn
# @param amount The amount of tokens that were withdrawn
event Withdrawn:
    token: indexed(address)
    amount: uint256

# @notice Emitted when a flash loan is completed
# @param receiver The contract that received the funds
# @param token The ERC20 token that was loaned
# @param amount The amount of tokens that were loaned
event Flashloaned:
    receiver: indexed(IFlashBorrower)
    token: indexed(address)
    amount: uint256

@external
@payable
def __init__():
    """
    @notice initialization of state   
    """
    manager = msg.sender

@external
@payable
def execute(receiver: address, token: address, amount: uint256, data: bytes32):
    """
    @notice Request a flash loan
	@param receiver The contract that will receive the flash loan
	@param token The ERC20 token you want to borrow
	@param amount The amount of tokens you want to borrow
	@param data Data to forward to the receiver contract along with your flash loan
	@dev Make sure your contract implements the FlashBorrower interface!    
    """
    currentBalance: uint256 = IERC20(token).balanceOf(self)

    log Flashloaned(IFlashBorrower(receiver), token, amount)

    IERC20(token).transfer(receiver, amount)

    IFlashBorrower(receiver).onFlashLoan(token, amount, data)

    assert IERC20(token).balanceOf(self) >= currentBalance + self.getFee(token, amount), "Tokens not returned"

@internal
@view
def getFee(token: address, amount: uint256) -> uint256:
    """
	@notice Calculate the fee owed for the loaned tokens
	@param token The ERC20 token you're receiving your loan on
	@param amount The amount of tokens you're receiving
	@return The amount of tokens you need to pay as a fee    
    """    
    if (self.fees[token] == 0):
        return 0
    return (amount * self.fees[token]) / 10_000

@external
@view
def getFees(token: address, amount: uint256) -> uint256:
    """
	@notice Calculate the fee owed for the loaned tokens
	@param token The ERC20 token you're receiving your loan on
	@param amount The amount of tokens you're receiving
	@return The amount of tokens you need to pay as a fee    
    """        
    if (self.fees[token] == 0):
        return 0
    return (amount * self.fees[token]) / 10_000    

@external
@payable
def setFees(token: address, fee: uint256):
    """
	@notice Update the fee percentage for a specified ERC20 token, only available to the manager of the contract
	@param token The ERC20 token you're updating the fee percentage for
	@param fee The fee percentage for this token, multiplied by 100 (for example, 10% is 10_00)    
    """
    assert msg.sender == manager, "Unauthorized"
    assert fee < 100_00, "Invalid percentage"

    log FeeUpdated(token, fee)

    self.fees[token] = fee
    
@external
@payable
def withdraw(token: address, amount: uint256):
    """
    @dev Allows the owner to withdraw this contracts token balance
	@param token The ERC20 token you want to withdraw
	@param amount The amount of tokens to withdraw    
    """    
    assert msg.sender == manager, "Unauthorized"
    log Withdrawn(token, amount)
    IERC20(token).transfer(msg.sender, amount)