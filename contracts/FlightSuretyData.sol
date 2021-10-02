pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Account used to deploy contract
    address private contractOwner;               
    // Blocks all state changes throughout the contract if false
    bool private operational = true;

    address private authorizedCaller;

    struct AirlineData {
        bool isRegistered;
        bool awaitsFunding;
        bool exists;
    }

    //Mapping of registered airlines
    mapping( address => AirlineData ) private airlines;

    //Keeeping track ot the number of registered Airlines
    uint private nbrRegisteredAirlines = 0;

    uint private constant FUNDING_AMOUNT = 10 ether;

    //Keeps track of flights statuses
    mapping(bytes32 => uint8) private flightsStatuses;


    //Flights insurees as a mapping of a key representing
    //a hash of flights information pointing towards a list of addresses
    //of each insuree for the given flight
    mapping(bytes32 => address[]) private flightsInsurees;

    //Mapping holging the amounts being insured for the different flights
    mapping(bytes32 => uint ) private insuredAmounts;

    //Balances available to different addresses as a result
    //of insurance payment.
    mapping(address => uint ) private balances;

       

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address firstAirlineAddress
                                ) 
                                public 
    {
        contractOwner = msg.sender;

        //The first airline is added at deployment, without vote.
        registerAirline(firstAirlineAddress, false, true );
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
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
    * @dev Modifier that requires the "AuthorizedCaller" account to be the function caller
    * or, of course, the contract owner.
    */
    modifier requireAuthorizedCaller()
    {
        require(msg.sender == authorizedCaller || msg.sender == contractOwner, "Caller is not authorized");
        _;
    }


    modifier requireExactFunding()
    {
        require(msg.value == FUNDING_AMOUNT, "Exact funding amount required" );
        _;
    }

    modifier requirePositiveBalance( address insureeAddress )
    {
        require( balances[insureeAddress] > 0, "Positive balance required to make a withdrawal" );
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
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    function authorizeCaller( address caller )
                                        public
                                        requireContractOwner
    {
        //We set the authorized caller for the data function
        //NOTE: this could be implemented as a list for more modularity
        authorizedCaller = caller;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *       NOTE: it would be better to include a function to check the caller is only the application contract
    */   
    function registerAirline
                            (
                                address airlineAddress,
                                bool isRegistered,
                                bool awaitsFunding
                            )
                            public
    {
        //We initialize a placeholder which will containts the data
        AirlineData memory airlineData;
        if (!airlines[ airlineAddress ].exists) {
            //If the data foes not exists for this airline, we create a new one
            //with the provided values
            airlineData = AirlineData( isRegistered, awaitsFunding, true );
            //And we add it to the mapping
            airlines[ airlineAddress ] = airlineData;
        }
        else {
            //Otherwise, we update it
            airlines[ airlineAddress ].isRegistered = isRegistered;
            airlines[ airlineAddress ].awaitsFunding = awaitsFunding;
        }
        
        //Increments the counter if the airline is registered
        if (isRegistered) {
            nbrRegisteredAirlines = SafeMath.add(nbrRegisteredAirlines, 1);
        }

    }


    /*
     *This determines wheter a give address is a REGISTERED airline
     *
     */
    function isAirline
                    (
                        address airlineAddress
                    )
                    public
                    view
                    requireAuthorizedCaller
                    returns(bool)
                    
    {
        //Simply checks in the mapping if the Airline is registered
        return airlines[ airlineAddress ].isRegistered;
    }

    function getNumberOfRegisteredAirlines() external view
                                //requireAuthorizedCaller
                                returns(uint) {
        return nbrRegisteredAirlines;

    }
    
    function updateFlightStatus( bytes32 flightKey, uint8 statusCode ) external {
        //We simply update the mapping in the smart contract
        flightsStatuses[flightKey] = statusCode;
    }

    function getFlightInsurees( bytes32 flightKey )
                    external view returns( address[] memory )
    {
        return flightsInsurees[ flightKey ];
    }

    function getInsuredAmount( bytes32 insuredAmountKey )
                external view returns( uint )
    {
        return insuredAmounts[insuredAmountKey];
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (
                                address insureeAddress,
                                bytes32 amountKey,
                                bytes32 flightKey         
                            )
                            external
                            payable
                            requireAuthorizedCaller
    {
        
        
        bool alreadyInsured=false;
        for (uint i=0;i<flightsInsurees[ flightKey ].length; i++) {
            if (flightsInsurees[ flightKey ][i] == insureeAddress)
            {
                //The client has already insured this flight, we don't
                //need to add him to the list
                alreadyInsured = true;
                break;
            }
        }
        
        if (!alreadyInsured) {
            //We need to add the new insuree to the list.
            flightsInsurees[ flightKey ].push(insureeAddress);
        }
        
        //Note that the logic for max amount is handled in tha App contract
        insuredAmounts[ amountKey ] += msg.value;
        
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address insureeAddress,
                                    uint amount
                                )
                                external
                                requireAuthorizedCaller
    {
        //We simply add to the balance.
        balances[insureeAddress] = SafeMath.add(balances[insureeAddress], amount);
    }

    function getBalance( address insureeAddress ) 
                external
                view
                requireAuthorizedCaller
                returns(uint)
    {
        return balances[insureeAddress];
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                                address insureeAddress
                            )
                            external
                            requireAuthorizedCaller
                            requirePositiveBalance( insureeAddress )
    {
        //We save the amount available first
        uint amountAvailable = balances[insureeAddress];

        require( address(this).balance >= amountAvailable, "Not enough ether on the data contract to pay.");

        //We then set the balance of the insuree to 0 to avoid re-entry attack
        balances[insureeAddress] = 0;
        //Finally, we pay the insuree
        insureeAddress.transfer(amountAvailable);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (
                                address airlineAddress   
                            )
                            public
                            payable
                            requireExactFunding
                            requireAuthorizedCaller
    {
        //We make basic checks
        require( airlines[airlineAddress].exists, "Airline not yet registered" );
        require( !airlines[airlineAddress].isRegistered, "Airline already registered" );
        require( airlines[airlineAddress].awaitsFunding, "Airline must be awaiting funding" );

        //We update the airline to be marked as REGISTERED and not expecting funding anymore
        registerAirline( airlineAddress, true, false );

        
        

    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }



    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund(address(0));
    }


}

