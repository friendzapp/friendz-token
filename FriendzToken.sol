pragma solidity 0.4.19;

library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

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

contract Haltable is Ownable {

	// public variables
	bool public halted;

	modifier stopInEmergency() {
		require(!halted);

		_;
	}

	modifier stopInEmergencyNonOwners() {
		if(halted && msg.sender != owner)
			revert();

		_;
	}

	function halt() external onlyOwner {
		halted = true;
	}

	function unhalt() external onlyOwner {
		halted = false;
	}

}

contract Whitelisted is Ownable {

	// variables
	mapping (address => bool) public whitelist;

	// events
	event WhitelistChanged(address indexed account, bool state);

	// modifiers

	// checkes if the address is whitelisted
	modifier isWhitelisted(address _addr) {
		require(whitelist[_addr] == true);

		_;
	}

	// methods
	function setWhitelist(address _addr, bool _state) onlyOwner external {
		require(_addr != address(0));
		require(whitelist[_addr] != _state);

		whitelist[_addr] = _state;

		WhitelistChanged(_addr, _state);
	}

}

contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public constant returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

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

contract BurnableToken is BasicToken {
	// events
	event Burn(address indexed burner, uint256 amount);

	// reduce sender balance and Token total supply
	function burn(uint256 _value) public {
		balances[msg.sender] = balances[msg.sender].sub(_value);
		totalSupply = totalSupply.sub(_value);

		Burn(msg.sender, _value);
	}
}

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

	// constants

	// events
	event Approval(address indexed owner, address indexed spender, uint256 value);
	event UpdatedBlockingState(address indexed to, uint256 purchase, uint256 end_date, uint256 value);
	event CoOwnerSet(address indexed owner);
	event ReleaseDateChanged(address indexed from, uint256 date);

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

	// modifiers

	// checks if the address can transfer tokens
	modifier canTransfer(address _sender, uint256 _value) {
		require(_sender != address(0));

		require(
			(free_transfer) ||
			canTransferBefore(_sender) ||
			canTransferIfLocked(_sender, _value)
	 	);

	 	_;
	}

	// check if we're in a free-transfter state
	modifier isFreeTransfer() {
		require(free_transfer);

		_;
	}

	// check if we're in non free-transfter state
	modifier isBlockingTransfer() {
		require(!free_transfer);

		_;
	}

	// functions

	function canTransferBefore(address _sender) public view returns(bool) {
		return (
			_sender == owner ||
			_sender == presale_holder ||
			_sender == ico_holder ||
			_sender == reserved_holder ||
			_sender == wallet_holder
		);
	}

	function canTransferIfLocked(address _sender, uint256 _value) public view returns(bool) {
		uint256 after_math = balances[_sender].sub(_value);
		return (
			now >= RELEASE_DATE &&
		    after_math >= getMinimumAmount(_sender)
        );
	}

	// set co-owner, can be set to 0
	function setCoOwner(address _addr) onlyOwner public {
		require(_addr != co_owner);

		co_owner = _addr;

		CoOwnerSet(_addr);
	}

	// set release date
	function setReleaseDate(uint256 _date) onlyOwner public {
		require(_date > 0);
		require(_date != RELEASE_DATE);

		RELEASE_DATE = _date;

		ReleaseDateChanged(msg.sender, _date);
	}

	// calculate the amount of tokens an address can use
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

	// set blocking state to an address
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

	// all addresses can transfer tokens now
	function freeToken() public onlyOwner {
		free_transfer = true;
	}

	// override function using canTransfer on the sender address
	function transfer(address _to, uint _value) canTransfer(msg.sender, _value) public returns (bool success) {
		return super.transfer(_to, _value);
	}

	// transfer tokens from one address to another
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

	// erc20 functions
  	function approve(address _spender, uint256 _value) public returns (bool) {
	 	require(_value == 0 || allowed[msg.sender][_spender] == 0);

	 	allowed[msg.sender][_spender] = _value;
	 	Approval(msg.sender, _spender, _value);

	 	return true;
  	}

	function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
    	return allowed[_owner][_spender];
  	}

	/**
	* approve should be called when allowed[_spender] == 0. To increment
	* allowed value is better to use this function to avoid 2 calls (and wait until
	* the first transaction is mined)
	* From MonolithDAO Token.sol
	*/
	function increaseApproval (address _spender, uint256 _addedValue) public returns (bool success) {
		allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
		Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
		return true;
	}

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

contract Sale is Haltable {

	// usings
	using SafeMath for uint256;

	// public variables
	FriendzToken public token;
	address public wallet;
	uint256 public rate;
	string public name;
	mapping (address => uint256) invested_amount_wei;
	mapping (address => uint256) invested_amount_tokens;

	uint256 public raised_wei = 0;
	uint256 public raised_tokens = 0;
	uint256 public investor_count = 0;

	// events
	event Invested(address indexed investor, uint256 wei_amount, uint256 token_amout);
	event RateUpdated(address indexed from, uint256 value);

	function Sale(string _name, address _token, address _wallet, uint256 _rate) internal {
		// safety checks
		require(_token != address(0));
		require(_wallet != address(0));
		require(_rate > 0);

		// set owner
		owner = msg.sender;

		// assign variables
		token = FriendzToken(_token);
		wallet = _wallet;
		rate = _rate;
		name = _name;
	}

	function updateRate(uint256 _rate) onlyOwner public {
		require(_rate > 0);
		require(_rate != rate);

		rate = _rate;

		RateUpdated(msg.sender, _rate);
	}

	// assign tokens to the investor, abstract
	function assignTokens(address _to, uint256 _amount) internal;
}

contract PreSale is Sale, Whitelisted {

	// public variables
	address public holder;
	uint256 public start_date;
	uint256 public end_date;
	uint256 public discount;
	uint256 public available_tokens;

	// constants
	uint256 MINIMUM_INVESTMENT = 15 * 1 ether;

	// events
	event MinimumChanged(address indexed from, uint256 value);

	function PreSale(address _holder, string _name, address _token, address _wallet, uint256 _rate, uint256 _discount, uint256 _available_tokens, uint256 _start_date, uint256 _end_date) 
			 Sale(_name, _token, _wallet, _rate) public // extends 'Sale' contract
	{
		// safety checks
		require(_holder != address(0));
		require(_available_tokens > 0);
		require(_start_date > now);
		require(_end_date > now);
		require(_start_date < _end_date);

		// assign variables
		holder = _holder;
		discount = _discount;
		available_tokens = _available_tokens;
		start_date = _start_date;
		end_date = _end_date;
	}

	// checks if the presale is finished or not
	modifier canInvest() {
 		require(now >= start_date);
 		require(now < end_date);

		_;
	}

	// fallback function, the only one that can receive payments
	function () payable external {
		investInternal(msg.sender);
	}

	// internal function for handling payments
	function investInternal(address _to) canInvest isWhitelisted(_to) stopInEmergency internal {
		// safety checks
		require(_to != address(0));
		require(msg.value >= MINIMUM_INVESTMENT);

		uint256 value_wei = msg.value;
		uint256 new_rate = rate.mul(discount.add(100)).div(100);
		uint256 value_tokens = value_wei.mul(new_rate);

 		require(value_tokens > 0);

		// increase investor count only if it's their the first time
		if(invested_amount_wei[_to] == 0){
			investor_count = investor_count.add(1);
		}

		// update investor
		invested_amount_wei[_to] = invested_amount_wei[_to].add(value_wei);
		invested_amount_tokens[_to] = invested_amount_tokens[_to].add(value_tokens);

		// update amounts
		raised_wei = raised_wei.add(value_wei);
		raised_tokens = raised_tokens.add(value_tokens);
		
		// this will throw an error and revert in case 'value_tokens' is greater than 'available_tokens'
		available_tokens = available_tokens.sub(value_tokens);

		// send ether to the wallet
		wallet.transfer(value_wei);

		// assign tokens to investor
		assignTokens(_to, value_tokens);

 		Invested(_to, value_wei, value_tokens);
	}

	// change minimum investment amount
	function setMinimum(uint256 _value) onlyOwner external {
		require(_value > 0);
		require(_value != MINIMUM_INVESTMENT);

		MINIMUM_INVESTMENT = _value;

		MinimumChanged(msg.sender, _value);
	}

	// internal function for assigning tokens to an address
	function assignTokens(address _to, uint256 _value) internal {
		if(!token.transferFrom(holder, _to, _value))
			revert();
	}

}

contract TimeManager is Ownable {

	// usings
	using SafeMath for uint256;

	// defines
	struct TimeSlice {
		uint256 start; // start time
		uint256 end; // end time
		uint256 discount; // discount percentage
		bool active; // is active
		bool blocking; // in this period of time all tokens emitted are blocked
	}

	// public variables
	uint256 public constant MAX_SLICES = 10;
	TimeSlice[10] public time_slices; // max 10 slices

	// private variables
	uint256 private slice_count;
	bool private finished = false;

	// constants
	uint256 constant FINAL_SLICE_END = 1609372800; // 2020-12-31 00:00:00

	function TimeManager(uint256[] _slices) public {
		require(
			_slices.length % 4 == 0 && // gotta have 4 values per slice
			_slices.length.div(4) < MAX_SLICES.sub(1) // check we don't exceed max_slices
		);

		// our first slice must be a dummy one
		require(
			_slices[0] == 0 &&  // start
			_slices[1] == 0 	// end
		);

		uint count = _slices.length.div(4);

		require(count > 1); // we need more than one slice...

		for(uint i = 0; i < count; i++){
			time_slices[i].start 	= _slices[i * 4 + 0];
			time_slices[i].end 		= _slices[i * 4 + 1];
			time_slices[i].discount = _slices[i * 4 + 2];
			time_slices[i].blocking = _slices[i * 4 + 3] == 1;
			time_slices[i].active 	= true;
		}
		
		// create the last slice
		time_slices[count].start = time_slices[count - 1].end;
		time_slices[count].end = FINAL_SLICE_END;
		time_slices[count].active = false; // we can't buy tokens here

		// we set the end of our dummy slice to the start of our first 'real' slice
		time_slices[0].end = time_slices[1].start;
		time_slices[0].active = false; // we can't buy tokens here

		slice_count = count;
	}

	function getCurrentSlice() private constant returns(TimeSlice) {
		for(uint i = 0; i < slice_count; i++){
			if(time_slices[i].start <= now && time_slices[i].end > now){
				return time_slices[i];
			}
		}
	}
	
	function setSlice(uint256 _index, uint256 _start, uint256 _end, uint256 _discount, bool _active, bool _blocked) onlyOwner public {
	    require(_index < slice_count);
	    require(_start > 0);
	    require(_end > 0);
	    require(_start < _end);
	    
	    time_slices[_index].start = _start;
	    time_slices[_index].end = _end;
	    time_slices[_index].discount = _discount;
	    time_slices[_index].active = _active;
	    time_slices[_index].blocking = _blocked;
	}

	function calculateDiscount(uint256 _wei, uint256 _rate) public constant returns(uint256) {
		TimeSlice memory slice = getCurrentSlice();

		if(slice.active == false)
			return 0; // return 0 so that in Crowdsale.sol we'll fire an exception because we don't support 0-valued transactions

		return _wei.mul(_rate.mul(slice.discount.add(100)).div(100));
	}

	function isBlocked() public constant returns(bool) {
		TimeSlice memory slice = getCurrentSlice();
		return slice.blocking;
	}

	// this contract can't be payed
	function () payable public {
		revert();
	}

	// kill this contract once we've finished with him
	function kill() onlyOwner public {
		selfdestruct(this);
	}

}

contract Crowdsale is Sale, Whitelisted {

	// uninitialized public variables
	TimeManager public time_manager;
	address public holder;
	address public co_owner;
	uint256 public available;
	uint256 public MINIMUM_INVESTMENT = 0.1 * 1 ether;
	uint256 public KYC_REQUIRED = 5 * 1 ether;
	bool public finished = false;

	// constants
	uint256 constant BLOCKING_PERIOD = 1 years;

	event WhitelistChanged(address indexed investor, bool status);
	event CoOwnerSet(address indexed owner);
	event MinimumChanged(address indexed from, uint256 value);
	event KycChanged(address indexed from, uint256 value);

	function Crowdsale(address _holder, string _name, address _token, address _time_manager, address _wallet, uint256 _rate, uint256 _available) 
			 Sale(_name, _token, _wallet, _rate) public
	{
		// safety checks
		require(_time_manager != address(0));
		require(_holder != address(0));
		require(_available > 0);

		time_manager = TimeManager(_time_manager);
		holder = _holder;
		available = _available;
	}

	// checks if we have closed the crowdsale
	modifier notFinished() {
		require(!finished);

		_;
	}

	modifier canInvest(uint256 _value) {
		require(
			invested_amount_wei[msg.sender].add(_value) <= KYC_REQUIRED ||
			whitelist[msg.sender] == true
		);

		_;
	}

	// fallback function
	function () payable canInvest(msg.value) public {
		invest(msg.sender);
	}

	// end crawdsale
	function finish() onlyOwner public {
		finished = true;
	}

    // internal function for accepting payments and transfering tokens
	function invest(address _to) notFinished stopInEmergency internal {
		// minimum value
		require(msg.value >= MINIMUM_INVESTMENT);

		uint256 value_wei = msg.value;
		uint256 value_tokens = time_manager.calculateDiscount(value_wei, rate);

		// 'calculateDiscount' will return 0 if we can't buy tokens
		require(value_tokens > 0);

		// increase investor count only if it's their the first time
		if(invested_amount_wei[_to] == 0) {
			investor_count = investor_count.add(1);
		}

		// update investor
		invested_amount_wei[_to] = invested_amount_wei[_to].add(value_wei);
		invested_amount_tokens[_to] = invested_amount_tokens[_to].add(value_tokens);

		// update amounts
		raised_wei = raised_wei.add(value_wei);
		raised_tokens = raised_tokens.add(value_tokens);
		
		// it will throw if 'available' is less than 'value_tokens', this is our HARD CAP
		available = available.sub(value_tokens);

		// send ether to the wallet
		wallet.transfer(value_wei);

		// assign tokens to investor
		assignTokens(_to, value_tokens);

		Invested(_to, value_wei, value_tokens);
	}

	// internal function for assigning tokens to an address
	function assignTokens(address _to, uint256 _value) internal {
		if(!token.transferFrom(holder, _to, _value))
			revert();

		if(time_manager.isBlocked()){
			uint256 release_date = token.RELEASE_DATE();
			uint256 end = release_date.add(BLOCKING_PERIOD);
			require(end >= token.RELEASE_DATE());

			token.setBlockingState(_to, end, _value);
		}
	}

	// change minimum investment amount
	function setMinimum(uint256 _value) onlyOwner external {
		require(_value > 0);

		MINIMUM_INVESTMENT = _value;

		MinimumChanged(msg.sender, _value);
	}

	// change amount required for kyc
	function setMinimumForKYC(uint256 _value) onlyOwner external {
		require(_value > 0);

		KYC_REQUIRED = _value;

		KycChanged(msg.sender, _value);
	}

	// set a co-owner
	function setCoOwner(address _owner) onlyOwner external {
		co_owner = _owner;

		CoOwnerSet(_owner);
	}

}