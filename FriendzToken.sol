pragma solidity 0.4.19;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

	/**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    require(newOwner != owner);

    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public constant returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances.
 */
contract BasicToken is ERC20Basic {
  using SafeMath for uint256;

  mapping(address => uint256) balances;

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));
    require(_value > 0);

    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public constant returns (uint256 balance) {
    return balances[_owner];
  }

}

/**
 * @title Burnable Token
 * @dev Token that can be irreversibly burned (destroyed).
 */
contract BurnableToken is BasicToken {
	
	event Burn(address indexed burner, uint256 amount);

	/** 
	 * @dev Burns a specific amount of tokens.
	 * @param _value The amount of tokens to be burned.
	 */
	function burn(uint256 _value) public {
		balances[msg.sender] = balances[msg.sender].sub(_value);
		totalSupply = totalSupply.sub(_value);

		Burn(msg.sender, _value);
	}
}

/**
 * @title Friendz Token
 * @dev The offcial Friendz Token contract.
 */
contract FriendzToken is BurnableToken, Ownable {

	// public variables
	mapping(address => uint256) public release_dates;
	mapping(address => uint256) public purchase_dates;
	mapping(address => uint256) public blocked_amounts;
	mapping (address => mapping (address => uint256)) public allowed;
	bool public free_transfer = false;
	uint256 public RELEASE_DATE = 1522540800; // 1th april 2018 00:00 UTC

	// private variables
	address private co_owner;
	address private presale_holder = 0x1ea128767610c944Ff9a60E4A1Cbd0C88773c17c;
	address private ico_holder = 0x0047051DCd27F8b299B4AEd14800E6ECBD0dE701;
	address private reserved_holder = 0x26226CfaB092C89eF3D79653D692Cc1425a0B907;
	address private wallet_holder = 0xBF0B56276e90fc4f0f1e2Ec66fa418E30E717215;

	// ERC20 variables
	string public name;
	string public symbol;
	uint256 public decimals;

	// events
	event Approval(address indexed owner, address indexed spender, uint256 value);
	event UpdatedBlockingState(address indexed to, uint256 purchase, uint256 end_date, uint256 value);
	event CoOwnerSet(address indexed owner);
	event ReleaseDateChanged(address indexed from, uint256 date);

	/*
	 * @dev Friendz Token's contructor
	 * @param _name The name of the token.
	 * @param _symbol A three-letter symbold of the token.
	 * @param _decimals The decimals of the tokens.
	 * @param _supply The total supply of the token.
	 */
	function FriendzToken(string _name, string _symbol, uint256 _decimals, uint256 _supply) public {
		// safety checks
		require(_decimals > 0);
		require(_supply > 0);

		// assign variables
		name = _name;
		symbol = _symbol;
		decimals = _decimals;
		totalSupply = _supply;

		// assign the total supply to the owner
		balances[owner] = _supply;
	}

	/**
	 * @dev Modifier used to check if an address is able to transfer a certain amount of tokens.
	 * @param _sender The transaction sender.
	 * @param _value The amount to transfer in tokens.
	 */
	modifier canTransfer(address _sender, uint256 _value) {
		require(_sender != address(0));

		require(
			(free_transfer) ||
			canTransferBefore(_sender) ||
			canTransferIfLocked(_sender, _value)
	 	);

	 	_;
	}

	/**
	 * @dev Modifier used to check if the `free_token` variable is set to True. 
	 */
	modifier isFreeTransfer() {
		require(free_transfer);

		_;
	}

	/**
	 * @dev Modifier used to check if the `free_token` variable is set to False. 
	 */
	modifier isBlockingTransfer() {
		require(!free_transfer);

		_;
	}

	/**
	 * @dev Checks if the sender address is one of those who could transfer tokens before the start of the ICO.
	 * @param _sender The transaction sender.
	 * @return True or False.
	 */
	function canTransferBefore(address _sender) public view returns(bool) {
		return (
			_sender == owner ||
			_sender == presale_holder ||
			_sender == ico_holder ||
			_sender == reserved_holder ||
			_sender == wallet_holder
		);
	}

	/**
	 * @dev Checks if the sender address can send a certain amount of tokens if they have got some locked balance.
	 * @param _sender The transaction sender.
	 * @param _value The amount of tokens to transfer.
	 * @return True or False.
	 */
	function canTransferIfLocked(address _sender, uint256 _value) public view returns(bool) {
		uint256 after_math = balances[_sender].sub(_value);
		return (
			now >= RELEASE_DATE &&
		    after_math >= getMinimumAmount(_sender)
        );
	}

	/**
	 * @dev Sets the `co_owner` variable to a new address.
	 * @param _addr The new co-owner address.
	 */
	function setCoOwner(address _addr) onlyOwner public {
		require(_addr != co_owner);

		co_owner = _addr;

		CoOwnerSet(_addr);
	}

	/**
	 * @dev Sets the relase date of all the tokens, after this date transactions can be made.
	 * @param _date The release date in unix epoch.
	 */
	function setReleaseDate(uint256 _date) onlyOwner public {
		require(_date > 0);
		require(_date != RELEASE_DATE);

		RELEASE_DATE = _date;

		ReleaseDateChanged(msg.sender, _date);
	}

	/**
		* @dev Returns the minimum amount of tokens an address has to be in their balance.
		* @param _addr The address to check.
		* @return The amount of tokens still locked.
		*/
	function getMinimumAmount(address _addr) constant public returns (uint256) {
		// if the address ha no limitations just return 0
		if(blocked_amounts[_addr] == 0x0)
			return 0x0;

		// if the purchase date is in the future block all the tokens
		if(purchase_dates[_addr] > now){
			return blocked_amounts[_addr];
		}

		uint256 alpha = uint256(now).sub(purchase_dates[_addr]); // absolute purchase date
		uint256 beta = release_dates[_addr].sub(purchase_dates[_addr]); // absolute token release date
		uint256 tokens = blocked_amounts[_addr].sub(alpha.mul(blocked_amounts[_addr]).div(beta)); // T - (α * T) / β

		return tokens;
	}

	/**
	 * @dev Sets the amount of tokens an account has locked, used during ICO.
	 * @param _addr The address in question.
	 * @param _end The release date of the locked amount.
	 * @param _value The amount of tokens to lock.
	 */
	function setBlockingState(address _addr, uint256 _end, uint256 _value) isBlockingTransfer public {
		// only the onwer and the co-owner can call this function
		require(
			msg.sender == owner ||
			msg.sender == co_owner
		);
		require(_addr != address(0));

		uint256 final_value = _value;

		if(release_dates[_addr] != 0x0){
			// if it's not the first time this function is beign called for this address
			// update its information instead of setting them (add value to previous value)
			final_value = blocked_amounts[_addr].add(_value);
		}

		release_dates[_addr] = _end;
		purchase_dates[_addr] = RELEASE_DATE;
		blocked_amounts[_addr] = final_value;

		UpdatedBlockingState(_addr, _end, RELEASE_DATE, final_value);
	}

	/**
	 * @dev Unlock all tokens.
	 */
	function freeToken() public onlyOwner {
		free_transfer = true;
	}

	/**
	 * @dev Override to add the modifier `canTransfer`.
	 */
	function transfer(address _to, uint _value) canTransfer(msg.sender, _value) public returns (bool success) {
		return super.transfer(_to, _value);
	}

	/**
	 * @dev Transfer an amount of tokens from one address to another.
	 * @param _from The address where the tokens should be taken from.
	 * @param _to The address where the tokens should be sent.
	 * @param _value The amount of tokens to send.
	 * @return True on success.
	 */
	function transferFrom(address _from, address _to, uint _value) canTransfer(_from, _value) public returns (bool success) {
		require(_from != address(0));
		require(_to != address(0));

	    // SafeMath.sub will throw if there is not enough balance.
	    balances[_from] = balances[_from].sub(_value);
	    balances[_to] = balances[_to].add(_value);
		allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value); // this will throw if we don't have enough allowance

	    // this event comes from BasicToken.sol
	    Transfer(_from, _to, _value);

	    return true;
	}

	/**
	 * @dev Allow an amount of tokens to be spent from another address.
	 * @param _spender The spender address.
	 * @param _value The amount of tokens to allow.
	 * @return True on success.
	 */
  function approve(address _spender, uint256 _value) public returns (bool) {
	 	require(_value == 0 || allowed[msg.sender][_spender] == 0);

	 	allowed[msg.sender][_spender] = _value;
	 	Approval(msg.sender, _spender, _value);

	 	return true;
  }

  /**
   * @dev Returns The amount of tokens still to be spent by an address.
   * @param _owner The owner of the tokens.
   * @param _spender The tokens spender.
   * @return The amount of tokens remaining.
   */
	function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
   	return allowed[_owner][_spender];
  }

	/**
	 * @dev Increments the amount of tokens an address can spend.
	 * @param _spender The spender address.
	 * @param _addedValue The amount of tokens to add to the remaining ones.
	 * @return True on success.
	 */
	function increaseApproval (address _spender, uint256 _addedValue) public returns (bool success) {
		allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
		Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
		return true;
	}

	/**
	 * @dev Decrements the amount of tokens an address can spend.
	 * @param _spender The spender address.
	 * @param _addedValue The amount of tokens to subtract from the remaining ones.
	 * @return True on success.
	 */
	function decreaseApproval (address _spender, uint256 _subtractedValue) public returns (bool success) {
		uint256 oldValue = allowed[msg.sender][_spender];
		if (_subtractedValue >= oldValue) {
			allowed[msg.sender][_spender] = 0;
		} else {
			allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
		}
		Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
		return true;
	}

}