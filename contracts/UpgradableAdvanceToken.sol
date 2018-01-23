pragma solidity ^0.4.16;

/**
 * Math operations with safety checks
 */
contract SafeMath {
  function safeMul(uint a, uint b) internal returns (uint) {
    uint c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function safeDiv(uint a, uint b) internal returns (uint) {
    assert(b > 0);
    uint c = a / b;
    assert(a == b * c + a % b);
    return c;
  }

  function safeSub(uint a, uint b) internal returns (uint) {
    assert(b <= a);
    return a - b;
  }

  function safeAdd(uint a, uint b) internal returns (uint) {
    uint c = a + b;
    assert(c>=a && c>=b);
    return c;
  }

  function max64(uint64 a, uint64 b) internal constant returns (uint64) {
    return a >= b ? a : b;
  }

  function min64(uint64 a, uint64 b) internal constant returns (uint64) {
    return a < b ? a : b;
  }

  function max256(uint256 a, uint256 b) internal constant returns (uint256) {
    return a >= b ? a : b;
  }

  function min256(uint256 a, uint256 b) internal constant returns (uint256) {
    return a < b ? a : b;
  }

  function assert(bool assertion) internal {
    if (!assertion) {
      revert();
    }
  }
}


contract owned {
  address public owner;

  function owned() public {
    owner = msg.sender;
  }

  modifier onlyOwner {
    require(msg.sender == owner);
    _;
  }

  function transferOwnership(address newOwner) onlyOwner public {
    owner = newOwner;
  }
}


/**
 * Upgrade agent interface inspired by Lunyr.
 *
 * Upgrade agent transfers tokens to a new contract.
 * Upgrade agent itself can be the token contract, or just a middle man contract doing the heavy lifting.
 */
contract UpgradeAgent {

  uint public originalSupply;

  /** Interface marker */
  function isUpgradeAgent() public constant returns (bool) {
    return true;
  }

  function upgradeFrom(address _from, uint256 _value) public;

}

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) public; }

contract Tokens is owned, SafeMath {
  // Public variables of the token
  string public name = "JTest Coin"; // Set the name for display purposes
  string public symbol = "JTEST"; // Set the symbol for display purposes
  uint8 public decimals = 18; // 18 decimals is the strongly suggested default, avoid changing it
  uint256 public initialSupply = 38739144847;
  uint256 public totalSupply;
  string public version = "H1.0";       //human 0.1 standard. Just an arbitrary versioning scheme.

  // This creates an array with all balances
  mapping (address => uint256) public balanceOf;
  mapping (address => mapping (address => uint256)) public allowance;

  // This generates a public event on the blockchain that will notify clients
  event Transfer(address indexed from, address indexed to, uint256 value);

  // This notifies clients about the amount burnt
  event Burn(address indexed from, uint256 value);

  /**
   * Constrctor function
   *
   * Initializes contract with initial supply tokens to the creator of the contract
   */
  function Tokens() public {
    totalSupply = initialSupply * 10 ** uint256(decimals);                        // Update total supply
    balanceOf[msg.sender] = totalSupply;               // Give the creator all initial tokens
  }

  /**
   * Internal transfer, only can be called by this contract
   */
  function _transfer(address _from, address _to, uint _value) internal {
    // Prevent transfer to 0x0 address. Use burn() instead
    require(_to != 0x0);
    // Check if the sender has enough
    require(balanceOf[_from] >= _value);
    // Check for overflows
    require(balanceOf[_to] + _value > balanceOf[_to]);
    // Save this for an assertion in the future
    uint previousBalances = balanceOf[_from] + balanceOf[_to];
    // Subtract from the sender
    balanceOf[_from] -= _value;
    // Add the same to the recipient
    balanceOf[_to] += _value;
    Transfer(_from, _to, _value);
    // Asserts are used to use static analysis to find bugs in your code. They should never fail
    assert(balanceOf[_from] + balanceOf[_to] == previousBalances);
  }

  /**
   * Transfer tokens
   *
   * Send `_value` tokens to `_to` from your account
   *
   * @param _to The address of the recipient
   * @param _value the amount to send
   */
  function transfer(address _to, uint256 _value) public {
    _transfer(msg.sender, _to, _value);
  }

  /**
   * Transfer tokens from other address
   *
   * Send `_value` tokens to `_to` in behalf of `_from`
   *
   * @param _from The address of the sender
   * @param _to The address of the recipient
   * @param _value the amount to send
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
    require(_value <= allowance[_from][msg.sender]);     // Check allowance
    allowance[_from][msg.sender] -= _value;
    _transfer(_from, _to, _value);
    return true;
  }

  /**
   * Set allowance for other address
   *
   * Allows `_spender` to spend no more than `_value` tokens in your behalf
   *
   * @param _spender The address authorized to spend
   * @param _value the max amount they can spend
   */
  function approve(address _spender, uint256 _value) public
  returns (bool success) {
    allowance[msg.sender][_spender] = _value;
    return true;
  }

  /**
   * Set allowance for other address and notify
   *
   * Allows `_spender` to spend no more than `_value` tokens in your behalf, and then ping the contract about it
   *
   * @param _spender The address authorized to spend
   * @param _value the max amount they can spend
   * @param _extraData some extra information to send to the approved contract
   */
  function approveAndCall(address _spender, uint256 _value, bytes _extraData)
  public
  returns (bool success) {
    tokenRecipient spender = tokenRecipient(_spender);
    if (approve(_spender, _value)) {
      spender.receiveApproval(msg.sender, _value, this, _extraData);
      return true;
    }
  }

  /**
   * Destroy tokens
   *
   * Remove `_value` tokens from the system irreversibly
   *
   * @param _value the amount of money to burn
   */
  function burn(uint256 _value) public returns (bool success) {
    require(balanceOf[msg.sender] >= _value);   // Check if the sender has enough
    balanceOf[msg.sender] -= _value;            // Subtract from the sender
    totalSupply -= _value;                      // Updates totalSupply
    Burn(msg.sender, _value);
    return true;
  }

  /**
   * Destroy tokens from other account
   *
   * Remove `_value` tokens from the system irreversibly on behalf of `_from`.
   *
   * @param _from the address of the sender
   * @param _value the amount of money to burn
   */
  function burnFrom(address _from, uint256 _value) public returns (bool success) {
    require(balanceOf[_from] >= _value);                // Check if the targeted balance is enough
    require(_value <= allowance[_from][msg.sender]);    // Check allowance
    balanceOf[_from] -= _value;                         // Subtract from the targeted balance
    allowance[_from][msg.sender] -= _value;             // Subtract from the sender's allowance
    totalSupply -= _value;                              // Update totalSupply
    Burn(_from, _value);
    return true;
  }
}

/******************************************/
/*       ADVANCED TOKEN STARTS HERE       */
/******************************************/

contract AdvancedTokens is Tokens {

  uint256 public blockReward = 1 * (10**uint256(decimals));
  uint32 public halvingInterval = 210000;
  uint256 public blockNumber = 0; // how many blocks mined
  uint256 public totalSupply = 0;
  uint256 public target   = 0x0000ffff00000000000000000000000000000000000000000000000000000000; // i.e. difficulty. miner needs to find nonce, so that (hash(nonce+random) < target)
  uint256 public powLimit = 0x0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
  uint40 public lastMinedOn; // will be used to check how long did it take to mine
  uint256 public randomness;

  address public newContractAddress;

  mapping (address => bool) public frozenAccount;

  /** Contract / person who can set the upgrade path. This can be the same as team multisig wallet, as what it is with its default value. */
  address public upgradeMaster;

  /** The next contract where the tokens will be migrated. */
  UpgradeAgent public upgradeAgent;

  /** How many tokens we have upgraded by now. */
  uint256 public totalUpgraded;

  /* This generates a public event on the blockchain that will notify clients */
  event FrozenFunds(address target, bool frozen);

  /**
   * Upgrade states.
   *
   * - NotAllowed: The child contract has not reached a condition where the upgrade can bgun
   * - WaitingForAgent: Token allows upgrade, but we don't have a new agent yet
   * - ReadyToUpgrade: The agent is set, but not a single token has been upgraded yet
   * - Upgrading: Upgrade agent is set and the balance holders can upgrade their tokens
   *
   */
  enum UpgradeState {Unknown, NotAllowed, WaitingForAgent, ReadyToUpgrade, Upgrading}

  /**
   * Somebody has upgraded some of his tokens.
   */
  event Upgrade(address indexed _from, address indexed _to, uint256 _value);

  /**
   * New upgrade agent available.
   */
  event UpgradeAgentSet(address agent);

  /* Initializes contract with initial supply tokens to the creator of the contract */
  function AdvancedTokens() Tokens() public {
    lastMinedOn = uint40(block.timestamp);
    updateRandomness();
  }

  /* Internal transfer, only can be called by this contract */
  function _transfer(address _from, address _to, uint _value) internal {
    require (_to != 0x0);                               // Prevent transfer to 0x0 address. Use burn() instead
    require (balanceOf[_from] >= _value);               // Check if the sender has enough
    require (balanceOf[_to] + _value > balanceOf[_to]); // Check for overflows
    require(!frozenAccount[_from]);                     // Check if sender is frozen
    require(!frozenAccount[_to]);                       // Check if recipient is frozen
    balanceOf[_from] -= _value;                         // Subtract from the sender
    balanceOf[_to] += _value;                           // Add the same to the recipient
    Transfer(_from, _to, _value);
  }

  /// @notice Create `mintedAmount` tokens and send it to `target`
  /// @param target Address to receive the tokens
  /// @param mintedAmount the amount of tokens it will receive
  function mintToken(address target, uint256 mintedAmount) onlyOwner public {
    balanceOf[target] += mintedAmount;
    totalSupply += mintedAmount;
    Transfer(0, this, mintedAmount);
    Transfer(this, target, mintedAmount);
  }

  /// @notice `freeze? Prevent | Allow` `target` from sending & receiving tokens
  /// @param target Address to be frozen
  /// @param freeze either to freeze it or not
  function freezeAccount(address target, bool freeze) onlyOwner public {
    frozenAccount[target] = freeze;
    FrozenFunds(target, freeze);
  }

  /// update randomness, will be used to find next Nonce
  function updateRandomness() internal {
    randomness = uint256(sha3(sha3(uint256(block.blockhash(block.number-1)) + uint256(block.coinbase) + uint256(block.timestamp))));
  }

  /// returns `randomness` used in PoW calculations
  function getRamdomness() view returns (uint256 currentRandomness) {
    return randomness;
  }

  /// pure, accepts randomness & nonce and returns hash as int (which should be compared to target)
  function hash(uint256 nonce, uint256 currentRandomness) pure returns (uint256){
    return uint256(sha3(nonce+currentRandomness));
  }

  /// pure, accepts randomness, nonce & target and returns boolian whether work is good
  function checkProofOfWork(uint256 nonce, uint256 currentRandomness, uint256 currentTarget) pure returns (bool workAccepted){
    return uint256(hash(nonce, currentRandomness)) < currentTarget;
  }

  // accepts Nonce and tells whether it is good to mine
  function checkMine(uint256 nonce) view returns (bool success) {
    return checkProofOfWork(nonce, getRamdomness(), target);
  }

  /*
   accepts nonce aka "mining field", checks if it passess proof of work,
   rewards if it does
   */
  function mine(uint256 nonce) returns (bool success) {
    require(checkMine(nonce));

    Mine(msg.sender, blockReward, uint40(block.timestamp) - uint40(lastMinedOn)); // issuing event to those who listens for it

    balanceOf[msg.sender] += blockReward; // giving reward
    blockNumber += 1;
    totalSupply += blockReward; // increasing total supply
    updateRandomness();

    // difficulty retarget:
    var mul = (block.timestamp - lastMinedOn);
    if (mul > (60*2.5*2)) {
      mul = 60*2.5*2;
    }
    if (mul < (60*2.5/2)) {
      mul = 60*2.5/2;
    }
    target *= mul;
    target /= (60*2.5);

    if (target > powLimit) { // difficulty not lower than that
      target = powLimit;
    }

    lastMinedOn = uint40(block.timestamp); // tracking time to check how much PoW took in the future
    if (blockNumber % halvingInterval == 0) { // time to halve reward?
      blockReward /= 2;
      RewardHalved();
    }

    return true;
  }

  function setNewContractAddress(address newAddress) onlyOwner {
    newContractAddress = newAddress;
  }

  /**
   * Do not allow construction without upgrade master set.
   */
  function UpgradeableToken(address _upgradeMaster) {
    upgradeMaster = _upgradeMaster;
  }

  /**
   * Allow the token holder to upgrade some of their tokens to a new contract.
   */
  function upgrade(uint256 value) public {

    UpgradeState state = getUpgradeState();
    if(!(state == UpgradeState.ReadyToUpgrade || state == UpgradeState.Upgrading)) {
      // Called in a bad state
      throw;
    }

    // Validate input value.
    if (value == 0) throw;

    balanceOf[msg.sender] = safeSub(balanceOf[msg.sender], value);

    // Take tokens out from circulation
    totalSupply = safeSub(totalSupply, value);
    totalUpgraded = safeAdd(totalUpgraded, value);

    // Upgrade agent reissues the tokens
    upgradeAgent.upgradeFrom(msg.sender, value);
    Upgrade(msg.sender, upgradeAgent, value);
  }

  /**
   * Set an upgrade agent that handles
   */
  function setUpgradeAgent(address agent) external {

    if(!canUpgrade()) {
      // The token is not yet in a state that we could think upgrading
      throw;
    }

    if (agent == 0x0) throw;
    // Only a master can designate the next agent
    if (msg.sender != upgradeMaster) throw;
    // Upgrade has already begun for an agent
    if (getUpgradeState() == UpgradeState.Upgrading) throw;

    upgradeAgent = UpgradeAgent(agent);

    // Bad interface
    if(!upgradeAgent.isUpgradeAgent()) throw;
    // Make sure that token supplies match in source and target
    if (upgradeAgent.originalSupply() != totalSupply) throw;

    UpgradeAgentSet(upgradeAgent);
  }

  /**
   * Get the state of the token upgrade.
   */
  function getUpgradeState() public constant returns(UpgradeState) {
    if(!canUpgrade()) return UpgradeState.NotAllowed;
    else if(address(upgradeAgent) == 0x00) return UpgradeState.WaitingForAgent;
    else if(totalUpgraded == 0) return UpgradeState.ReadyToUpgrade;
    else return UpgradeState.Upgrading;
  }

  /**
   * Change the upgrade master.
   *
   * This allows us to set a new owner for the upgrade mechanism.
   */
  function setUpgradeMaster(address master) public {
    if (master == 0x0) throw;
    if (msg.sender != upgradeMaster) throw;
    upgradeMaster = master;
  }

  /**
   * Child contract can enable to provide the condition when the upgrade can begun.
   */
  function canUpgrade() public constant returns(bool) {
    return true;
  }

  event Mine(address indexed _miner, uint256 _reward, uint40 _seconds);
  event RewardHalved();

}