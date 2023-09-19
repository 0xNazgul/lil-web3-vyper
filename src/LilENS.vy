# @version ^0.3.9
"""
@title lil ens vyper
@custom:contract-name LilENS
@license GNU Affero General Public License v3.0
@author 0xNazgul
@notice Simple implementation of ENS
"""

# @notice Stores the current owner
owner: public(address)

# @notice Stores the registered names and their addresses
lookup: public(HashMap[String[100], address])

# @notice fee to register name
nameFee: public(uint256)

# @notice fee to update name
updateFee: public(uint256)

# @notice Emitted when owner is updated
# @param oldOwner The old owner
# @param newOwner The new owner
event NewOwner:
    oldOwner: indexed(address)
    newOwner: indexed(address)

# @notice Emitted when user registers a name
# @param amount The amount the user paid
# @param amount_fee The amount the user paid in fees
# @param name The name being registered
# @param sender The purchaser of the name
event Register:
    amount: uint256
    amount_fee: uint256
    name: String[100]
    sender: indexed(address)

# @notice Emitted when user updates their name to a new address
# @param amount The amount the user paid in fees
# @param name The name being updated
# @param newAddress The new address of the name
# @param sender The user updating their name
event Update:
    amount: uint256
    amount_fee: uint256
    name: String[100]
    newAddress: indexed(address)
    sender: indexed(address)

# @notice Emitted when owner updates name registration fee
# @param oldFee The old name registration fee
# @param newFee The new name registration fee
event NewNameFee:
    oldFee: indexed(uint256)
    newFee: indexed(uint256)

# @notice Emitted when owner updates name update fee
# @param oldOwner The old name update fee
# @param newOwner The new name update fee
event NewUpdateFee:
    oldFee: indexed(uint256)
    newFee: indexed(uint256)

# @notice Emitted when owner withdraws fees
# @param amount The amount the owner is withdrawing
event WithdrawFees:
    amount: indexed(uint256)

@external
@payable
def __init__(init_name_fee: uint256, init_update_fee: uint256):
    """
    @notice initialization of state
    @param init_name_fee The fee charged when a name is registered
    @param init_update_fee The fee charged when a name address is updated 
    """
    assert init_name_fee <= 1*10**18, "Name fee too high"
    assert init_update_fee <= 1*10**18, "Update fee too high"
    self.nameFee = init_name_fee
    self.updateFee = init_update_fee
    self.owner = msg.sender

@external
@payable
def register(name: String[100]):
    """
    @notice Registers a new name and point it to your address
    @param name The name to register
    """    
    name_cost: uint256 = len(name) * self.nameFee
    assert msg.value >= name_cost, "Not enough for fee"
    assert self.lookup[name] == empty(address), "Already Registered"
    self.lookup[name] = msg.sender

    if msg.value >= name_cost:
        send(msg.sender, msg.value - name_cost)

    log Register(msg.value, name_cost, name, msg.sender)

@external
@payable
def update(name: String[100], addr: address):
    """
    @notice Allows the owner of a name to point it to a different address
    @param name The name to update
    @param addr The new address this name should point to 
    """
    update_cost: uint256 = len(name) * self.updateFee
    assert msg.value >= update_cost, "Not enough for fee"
    assert self.lookup[name] == msg.sender, "Not your name"

    self.lookup[name] = addr

    if msg.value >= update_cost:
        send(msg.sender, msg.value - update_cost)

    log Update(msg.value, update_cost, name, addr, msg.sender)

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
def newNameFee(new_fee: uint256):
    """
    @notice Allows the owner to change the name fee
    @param new_fee The new fee to register a name
    """        
    assert new_fee <= 1*10**18, "Fee too high"
    assert msg.sender == self.owner, "Unauthorized"
    log NewNameFee(self.nameFee, new_fee)
    self.nameFee = new_fee
    
@external
def newUpdateFee(new_fee: uint256):
    """
    @notice Allows the owner to change the update name fee
    @param new_fee The new fee to update a name to a new address
    """
    assert new_fee <= 1*10**18, "Fee too high"
    assert msg.sender == self.owner, "Unauthorized"
    log NewUpdateFee(self.updateFee, new_fee)
    self.updateFee = new_fee

@external
def withdrawFees():
    """
    @notice Allows the owner to withdraw all of this contracts balance
    """    
    assert msg.sender == self.owner, "Unauthorized"
    log WithdrawFees(self.balance)
    send(msg.sender, self.balance)