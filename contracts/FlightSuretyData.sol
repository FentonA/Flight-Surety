pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/
    struct Airline{
        string airlineName; 
        address account;
        bool isRegistered;
        bool isFunded;
        uint256 fund;
    }

    uint256 internal airlineCount = 0;
    mapping(address => Airline) airlines;
    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    // struct to set our insurance clients

    struct Insurance{
        address insuredAccount;
        string insuredFlight;
        address airlineAccunt;
        uint256 amountInsured;
        uint256 timestamp;
    }

    mapping(bytes32 => Insurance[]) insurances;

    mapping(bytes32 => bool) private payoutCredit;

    mapping(address =>uint256) private creditToInsure;

    //mapping to set and keep list of authorized callers to this contract
    mapping(address => bool) private authorizeCallers;
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event AirlineRgistered(string airlineName, address indexed airline);

    event PurchasedInsurance(address indexed ariline, uint256 amount);

    event InsuranceCredited(address indexed insurance, string indexed flight, uint256 indexed timestamp);

    event InsurancePaidFor(address indexed account, uint256 amount);

    event AvailableCredit(address indexed airline, string indexed flightName, uint256 timestamp);

    event AirlineFunded(address indexed airline, uint256 amountFunded);

    event callAuthorized(address caller);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() public {
        contractOwner = msg.sender;
        _addAirline("American", contractOwner);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner(){
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    // modifier that lets only registered users add an airline 
    modifier registeredOnly(){
        require(airlines[msg.sender].isRegistered == true );
        _;
    }

    //modifer that onyl allows authorized callers to call the external function on this contract
    modifier requireAuthorizedCaller(){
        require(authorizeCallers[msg.sender] == true, "You are not authorized to call functions on this contract");
        _;
    }
    modifier isAirlineCheck(){
        require(airlines[msg.sender].isRegistered == true, "This sender isn't a registered airline");
        _;
    }
    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      

    function isOperational() external view returns(bool) {
        return operational;
    }

    //function that sets the authorized caller 
    function setAuthorizedCaller(address account)internal requireContractOwner {
        authorizeCallers[account] = true;
    }
    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    function isAirline(address airlineAccount) external view returns(bool) {
        return airlines[airlineAccount].isRegistered;
    }

    function getAirlineCount() external view returns(uint256) {
        return airlineCount;
    }

    function generateFlightKey( address airline, string flightName, uint256 timestamp) internal view returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flightName, timestamp));

    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function _addAirline(string _airlineName, address _account) internal registeredOnly {
        // require(!airlines[_account], "This Airline has already been added");
        airlines[_account] = Airline(_airlineName, _account, true, true, 0);
        airlineCount.add(1);
    }

     function registerAirline( string _airlineName, address _airlineAccount) external {
        _addAirline(_airlineName, _airlineAccount );
        
        emit AirlineRgistered(_airlineName, _airlineAccount);
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy(address insuranceAccount, address _airline, string _flightName, uint256 timestamp) external payable{
        require(msg.value >= 1 ether, "not enough ether to purchase this insurance" );
        bytes32 flightKey = generateFlightKey(_airline, _flightName, timestamp);
        airlines[_airline].fund = airlines[_airline].fund.add(msg.value);

        insurances[flightKey].push(Insurance(
            insuranceAccount, 
            _flightName,
            _airline,
            msg.value,
            timestamp
        ));

        emit PurchasedInsurance(_airline, msg.value);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(string _flightName, uint256 _creditPercentage, address airline, uint256 timestamp) external requireAuthorizedCaller{
        bytes32 flightKey = generateFlightKey(airline, _flightName, timestamp);
        require(!payoutCredit[flightKey], "This has already been credited" );
        
        for(uint i = 0; i< insurances[flightKey].length; i++){
            address insuredAccount = insurances[flightKey][i].insuredAccount;
            uint256 amountCrdited = insurances[flightKey][i].amountInsured.mul(_creditPercentage).div(100);
            creditToInsure[insuredAccount] = creditToInsure[insuredAccount].add(amountCrdited);
            airlines[airline].fund = airlines[airline].fund.sub(amountCrdited);

            emit InsuranceCredited(insuredAccount, _flightName, timestamp);

        }
        payoutCredit[flightKey] = true;
        emit AvailableCredit(airline, _flightName, timestamp);
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(address insuree) external requireAuthorizedCaller{
        uint paidAmount = creditToInsure[insuree];
        delete(creditToInsure[insuree]);
        insuree.transfer(paidAmount);
        emit InsurancePaidFor( insuree, paidAmount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund(address airline) public payable requireAuthorizedCaller{
       addFund(airline, msg.value);
       airlines[airline].isFunded = true;    
    }

    function addFund(address airlineAccount, uint256 amountToFund) private {
        airlines[airlineAccount].fund = airlines[airlineAccount].fund.add(amountToFund);
    }

    function getFlightKey(address airline, string memory flight, uint256 timestamp) internal returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable {
        fund(msg.sender);
        airlines[msg.sender].isFunded = true;
    }


}



