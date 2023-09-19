# @version ^0.3.9
"""
@title lil juicebox vyper
@custom:contract-name LilJuicebox
@license GNU Affero General Public License v3.0
@author 0xNazgul
@dev Simple implementation of Juicebox
"""

# @notice IProjecShare of ProjecShare and the 
# functions this contracts requires
interface IProjecShare:
    def setup(name_: String[25], symbol_: String[5], decimals_: uint8): payable
    def mint(owner: address, amount: uint256): nonpayable
    def burn_from(owner: address, amount: uint256): nonpayable

# @notice The address of the user who can withdraw funds and change the state of the campaign
manager: public(address)

# @notice The current state of the campaign
getState: public(State)

# @notice The address of the ERC20 token representing shares of this campaign
token: public(immutable(address))

# @notice The amount of ERC20 tokens to issue per ETH received
TOKENS_PER_ETH: public(constant(uint256)) = 1_000_000

# @notice Possible states of a campagin
enum State:
	CLOSED
	OPEN
	REFUNDING

# @notice Emitted when the manager renounces the contract, locking its current state forever
event Renounced:
    sender: address 

# @notice Emitted when the manager withdrawns a share of the raised funds
# @param amount The amount of ETH withdrawn
event Withdrawn:
    amount: uint256

# @notice Emitted when the state of the campaign is changed
# @param state The new state of the campaign
event StateUpdated:
    state: State 

# @notice Emitted when a contributor successfully claims a refund
# @param contributor The address of the contributor
# @param amount The amount of ETH refunded
event Refunded:
    contributor: indexed(address)
    amount: uint256

# @notice Emitted when a user contributes to the campaign
# @param contributor The address of the contributor
# @param amount The amount of ETH contributed
event Contributed:
    contributor: indexed(address)
    amount: uint256

@external
@payable
def __default__():
    """
    @notice This function ensures this contract can receive ETH
    """
    pass

@external
@payable
def __init__(name: String[25], symbol: String[5], project_share: address): 
    """
    @notice initialization of state 
	@notice Deploys a LilJuicebox instance with the specified name and symbol
	@param name The name of the ERC20 token
	@param symbol The symbol of the ERC20 token
    @param project_share The address of the master copy 
    """    
    self.manager = msg.sender
    self.getState = State.OPEN
    token = create_forwarder_to(project_share)    
    IProjecShare(token).setup(name, symbol, 18)

@external
@payable
def contribute():
    """
    @notice Contribute to the campaign by sending ETH, if contributions are open
    """
    assert self.getState == State.OPEN, "Contributions closed"

    log Contributed(msg.sender, msg.value)

    IProjecShare(token).mint(msg.sender, msg.value * TOKENS_PER_ETH)

@external
@payable
def refund(amount: uint256):
    """
    @notice Receive a refund for your contribution to the campaign, if refunds are open
    @param amount The amount the user would like to refund
    """
    assert self.getState == State.REFUNDING, "Refunds closed"

    refundETH: uint256 = amount / TOKENS_PER_ETH

    log Refunded(msg.sender, refundETH)

    IProjecShare(token).burn_from(msg.sender, amount)

    send(msg.sender, refundETH)

@external
@payable
def withdraw():
    """
    @notice Allows the owner to withdraw all of this contracts balance
    """    
    assert msg.sender == self.manager, "Unauthorized"
    log Withdrawn(self.balance)
    send(msg.sender, self.balance)

@external
@payable
def setState(state: State):
    """
	@notice Update the state of the campaign, only available to the manager of the campaign
	@param state The new state of the campaign    
    """
    assert msg.sender == self.manager, "Unauthorized"
    self.getState = state
    log StateUpdated(state)

@external
@payable
def renounce():
    """
    @notice Renounce ownership of the campaign, effectively locking all settings in place. Only available to the manager of the campaign    
    """
    assert msg.sender == self.manager, "Unauthorized"

    log Renounced(msg.sender)

    self.manager = empty(address)