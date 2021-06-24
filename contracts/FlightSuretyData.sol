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
    }

    uint256 internal airlineCount = 0;
    mapping(address => Airline) airlines;
    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    uint256 constant public insurancePrice = 1 ether;
    // struct to set our insurance clients

    struct Insurance{
        address insureeAddress;
        uint256 inusranceCount;
        address airlineInsured;
        uint256 totalAmountInsured;
    }

    mapping(bytes32 => Insurance) insurances;

    //mapping to set and keep list of authorized callers to this contract
    mapping(address => bool) private authorizeCallers;
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


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
        airlines[_account] = Airline(_airlineName, _account, true);
        airlineCount.add(1);
    }

     function registerAirline( string _airlineName, address _airlineAccount) external {
        _addAirline(_airlineName, _airlineAccount );
        
    }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy() external payable{
        require(msg.value >= insurancePrice, "not enough ether to purchase this insurance" );
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees() external pure{
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay() external pure{
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund() public payable{
    }

    function getFlightKey(address airline, string memory flight, uint256 timestamp) pure internal returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable {
        fund();
    }


}



