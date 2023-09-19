# @version ^0.3.9
"""
@title Project Share ERC20
@custom:contract-name ProjectShare
@license GNU Affero General Public License v3.0
@author 0xNazgul
@dev A modified version of Snekmate's ERC20 token representing a share on LilJuicebox
"""

# @dev We import and implement the `ERC20` interface,
# which is a built-in interface of the Vyper compiler.
from vyper.interfaces import ERC20
implements: ERC20

# @notice The manager of this campaign
manager: public(address)

# @notice Returns the decimals places of the token.
# The default value is 18.
decimals: public(uint8)

# @notice Returns the name of the token.
name: public(String[25])

# @notice Returns the symbol of the token.
symbol: public(String[5])

# @notice Returns the amount of tokens in existence.
totalSupply: public(uint256)

# @notice Returns the amount of tokens owned by an `address`.
balanceOf: public(HashMap[address, uint256])

# @notice Returns the remaining number of tokens that a
# `spender` will be allowed to spend on behalf of
# `owner` through `transferFrom`. 
allowance: public(HashMap[address, HashMap[address, uint256]])

# @notice Emitted when a transfer occurs
# @param owenr The owner of the token
# @param to The address of the token receiver
# @param amount The amount of token being transferred
event Transfer:
    owner: indexed(address)
    to: indexed(address)
    amount: uint256


# @notice Emitted when the allowance of a `spender`
# for an `owner` is set 
# @param owner The owner of the token
# @param spender The spender of the owner's token
# @param amount The amount of token approved
event Approval:
    owner: indexed(address)
    spender: indexed(address)
    amount: uint256

@external
@payable
def __init__(name_: String[25], symbol_: String[5], decimals_: uint8):
    """
    @notice initialization of state for mastercopy
    @param name_ The name of the token.
    @param symbol_ The symbol of the token.
    @param decimals_ The decimals of the token
    """    
    self.manager = msg.sender 
    self.name = name_
    self.symbol = symbol_
    self.decimals =  decimals_

@external
def setup(name_: String[25], symbol_: String[5], decimals_: uint8):
    """
    @notice initialization of state after create forwarder to
    @param name_ The name of the token.
    @param symbol_ The symbol of the token.
    @param decimals_ The decimals of the token
    """    
    self.manager = msg.sender  
    self.name = name_
    self.symbol = symbol_
    self.decimals =  decimals_    

@external
def transfer(to: address, amount: uint256) -> bool:
    """
    @dev Moves `amount` tokens from the caller's
         account to `to`.
    @notice Note that `to` cannot be the zero address.
            Also, the caller must have a balance of at
            least `amount`.
    @param to The 20-byte receiver address.
    @param amount The 32-byte token amount to be transferred.
    @return bool The verification whether the transfer succeeded
            or failed. Note that the function reverts instead
            of returning `False` on a failure.
    """
    self._transfer(msg.sender, to, amount)
    return True


@external
def approve(spender: address, amount: uint256) -> bool:
    """
    @dev Sets `amount` as the allowance of `spender`
         over the caller's tokens.
    @notice WARNING: Note that if `amount` is the maximum
            `uint256`, the allowance is not updated on
            `transferFrom`. This is semantically equivalent
            to an infinite approval. Also, `spender` cannot
            be the zero address.

            IMPORTANT: Beware that changing an allowance
            with this method brings the risk that someone
            may use both the old and the new allowance by
            unfortunate transaction ordering. One possible
            solution to mitigate this race condition is to
            first reduce the spender's allowance to 0 and
            set the desired amount afterwards:
            https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729.
    @param spender The 20-byte spender address.
    @param amount The 32-byte token amount that is
           allowed to be spent by the `spender`.
    @return bool The verification whether the approval operation
            succeeded or failed. Note that the function reverts
            instead of returning `False` on a failure.
    """
    self._approve(msg.sender, spender, amount)
    return True


@external
def transferFrom(owner: address, to: address, amount: uint256) -> bool:
    """
    @dev Moves `amount` tokens from `owner`
         to `to` using the allowance mechanism.
         The `amount` is then deducted from the
         caller's allowance.
    @notice Note that `owner` and `to` cannot
            be the zero address. Also, `owner`
            must have a balance of at least `amount`.
            Eventually, the caller must have allowance
            for `owner`'s tokens of at least `amount`.

            WARNING: The function does not update the
            allowance if the current allowance is the
            maximum `uint256`.
    @param owner The 20-byte owner address.
    @param to The 20-byte receiver address.
    @param amount The 32-byte token amount to be transferred.
    @return bool The verification whether the transfer succeeded
            or failed. Note that the function reverts instead
            of returning `False` on a failure.
    """
    self._spend_allowance(owner, msg.sender, amount)
    self._transfer(owner, to, amount)
    return True


@external
def increase_allowance(spender: address, added_amount: uint256) -> bool:
    """
    @dev Atomically increases the allowance granted to
         `spender` by the caller.
    @notice This is an alternative to `approve` that can
            be used as a mitigation for the problems
            described in https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729.
            Note that `spender` cannot be the zero address.
    @param spender The 20-byte spender address.
    @param added_amount The 32-byte token amount that is
           added atomically to the allowance of the `spender`.
    @return bool The verification whether the allowance increase
            operation succeeded or failed. Note that the function
            reverts instead of returning `False` on a failure.
    """
    self._approve(msg.sender, spender, self.allowance[msg.sender][spender] + added_amount)
    return True


@external
def decrease_allowance(spender: address, subtracted_amount: uint256) -> bool:
    """
    @dev Atomically decreases the allowance granted to
         `spender` by the caller.
    @notice This is an alternative to `approve` that can
            be used as a mitigation for the problems
            described in https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729.
            Note that `spender` cannot be the zero address.
            Also, `spender` must have an allowance for
            the caller of at least `subtracted_amount`.
    @param spender The 20-byte spender address.
    @param subtracted_amount The 32-byte token amount that is
           subtracted atomically from the allowance of the `spender`.
    @return bool The verification whether the allowance decrease
            operation succeeded or failed. Note that the function
            reverts instead of returning `False` on a failure.
    """
    current_allowance: uint256 = self.allowance[msg.sender][spender]
    assert current_allowance >= subtracted_amount, "ERC20: decreased allowance below zero"
    self._approve(msg.sender, spender, unsafe_sub(current_allowance, subtracted_amount))
    return True


@external
def burn(amount: uint256):
    """
    @dev Destroys `amount` tokens from the caller.
    @param amount The 32-byte token amount to be destroyed.
    """
    assert msg.sender == self.manager, "Unauthorized"

    self._burn(msg.sender, amount)


@external
def burn_from(owner: address, amount: uint256):
    """
    @dev Destroys `amount` tokens from `owner`,
         deducting from the caller's allowance.
    @notice Note that `owner` cannot be the
            zero address. Also, the caller must
            have an allowance for `owner`'s tokens
            of at least `amount`.
    @param owner The 20-byte owner address.
    @param amount The 32-byte token amount to be destroyed.
    """
    assert msg.sender == self.manager, "Unauthorized"

    self._burn(owner, amount)


@external
def mint(owner: address, amount: uint256):
    """
    @dev Creates `amount` tokens and assigns them to `owner`.
    @notice Only authorised minters can access this function.
            Note that `owner` cannot be the zero address.
    @param amount The 32-byte token amount to be created.
    """
    assert msg.sender == self.manager, "Unauthorized"

    self._mint(owner, amount)


@internal
def _transfer(owner: address, to: address, amount: uint256):
    """
    @dev Moves `amount` tokens from the owner's
         account to `to`.
    @notice Note that `owner` and `to` cannot be
            the zero address. Also, `owner` must
            have a balance of at least `amount`.
    @param owner The 20-byte owner address.
    @param to The 20-byte receiver address.
    @param amount The 32-byte token amount to be transferred.
    """
    assert owner != empty(address), "ERC20: transfer from the zero address"
    assert to != empty(address), "ERC20: transfer to the zero address"

    self._before_token_transfer(owner, to, amount)

    owner_balanceOf: uint256 = self.balanceOf[owner]
    assert owner_balanceOf >= amount, "ERC20: transfer amount exceeds balance"
    self.balanceOf[owner] = unsafe_sub(owner_balanceOf, amount)
    self.balanceOf[to] = unsafe_add(self.balanceOf[to], amount)
    log Transfer(owner, to, amount)

    self._after_token_transfer(owner, to, amount)


@internal
def _mint(owner: address, amount: uint256):
    """
    @dev Creates `amount` tokens and assigns
         them to `owner`, increasing the
         total supply.
    @notice This is an `internal` function without
            access restriction. Note that `owner`
            cannot be the zero address.
    @param owner The 20-byte owner address.
    @param amount The 32-byte token amount to be created.
    """
    assert owner != empty(address), "ERC20: mint to the zero address"

    self._before_token_transfer(empty(address), owner, amount)

    self.totalSupply += amount
    self.balanceOf[owner] = unsafe_add(self.balanceOf[owner], amount)
    log Transfer(empty(address), owner, amount)

    self._after_token_transfer(empty(address), owner, amount)


@internal
def _burn(owner: address, amount: uint256):
    """
    @dev Destroys `amount` tokens from `owner`,
         reducing the total supply.
    @notice Note that `owner` cannot be the
            zero address. Also, `owner` must
            have at least `amount` tokens.
    @param owner The 20-byte owner address.
    @param amount The 32-byte token amount to be destroyed.
    """
    assert owner != empty(address), "ERC20: burn from the zero address"

    self._before_token_transfer(owner, empty(address), amount)

    account_balance: uint256 = self.balanceOf[owner]
    assert account_balance >= amount, "ERC20: burn amount exceeds balance"
    self.balanceOf[owner] = unsafe_sub(account_balance, amount)
    self.totalSupply = unsafe_sub(self.totalSupply, amount)
    log Transfer(owner, empty(address), amount)

    self._after_token_transfer(owner, empty(address), amount)


@internal
def _approve(owner: address, spender: address, amount: uint256):
    """
    @dev Sets `amount` as the allowance of `spender`
         over the `owner`'s tokens.
    @notice Note that `owner` and `spender` cannot
            be the zero address.
    @param owner The 20-byte owner address.
    @param spender The 20-byte spender address.
    @param amount The 32-byte token amount that is
           allowed to be spent by the `spender`.
    """
    assert owner != empty(address), "ERC20: approve from the zero address"
    assert spender != empty(address), "ERC20: approve to the zero address"

    self.allowance[owner][spender] = amount
    log Approval(owner, spender, amount)


@internal
def _spend_allowance(owner: address, spender: address, amount: uint256):
    """
    @dev Updates `owner`'s allowance for `spender`
         based on spent `amount`.
    @notice WARNING: Note that it does not update the
            allowance `amount` in case of infinite
            allowance. Also, it reverts if not enough
            allowance is available.
    @param owner The 20-byte owner address.
    @param spender The 20-byte spender address.
    @param amount The 32-byte token amount that is
           allowed to be spent by the `spender`.
    """
    current_allowance: uint256 = self.allowance[owner][spender]
    if (current_allowance != max_value(uint256)):
        # The following line allows the commonly known address
        # poisoning attack, where `transferFrom` instructions
        # are executed from arbitrary addresses with an `amount`
        # of 0. However, this poisoning attack is not an on-chain
        # vulnerability. All assets are safe. It is an off-chain
        # log interpretation issue.
        assert current_allowance >= amount, "ERC20: insufficient allowance"
        self._approve(owner, spender, unsafe_sub(current_allowance, amount))


@internal
def _before_token_transfer(owner: address, to: address, amount: uint256):
    """
    @dev Hook that is called before any transfer of tokens.
         This includes minting and burning.
    @notice The calling conditions are:
            - when `owner` and `to` are both non-zero,
              `amount` of `owner`'s tokens will be
              transferred to `to`,
            - when `owner` is zero, `amount` tokens will
              be minted for `to`,
            - when `to` is zero, `amount` of `owner`'s
              tokens will be burned,
            - `owner` and `to` are never both zero.
    @param owner The 20-byte owner address.
    @param to The 20-byte receiver address.
    @param amount The 32-byte token amount to be transferred.
    """
    pass


@internal
def _after_token_transfer(owner: address, to: address, amount: uint256):
    """
    @dev Hook that is called after any transfer of tokens.
         This includes minting and burning.
    @notice The calling conditions are:
            - when `owner` and `to` are both non-zero,
              `amount` of `owner`'s tokens has been
              transferred to `to`,
            - when `owner` is zero, `amount` tokens
              have been minted for `to`,
            - when `to` is zero, `amount` of `owner`'s
              tokens have been burned,
            - `owner` and `to` are never both zero.
    @param owner The 20-byte owner address.
    @param to The 20-byte receiver address.
    @param amount The 32-byte token amount that has
           been transferred.
    """
    pass
