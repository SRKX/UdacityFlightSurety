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

    struct AirlineData {
        bool isRegistered;
        bool awaitsFunding;
        int currentVotes;
        bool exists;
    }

    //Mapping of registered airlines
    mapping( address => AirlineData ) private airlines;


    //Keeeping track ot the number of registered Airlines
    uint nbrRegisteredAirlines = 0;

    uint private constant MIN_REGISTERED_AIRLINES_TO_VOTE = 4;

    uint private constant FUNDING_AMOUNT = 10 ether;
       

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
        _registerAirlineData(firstAirlineAddress, false, true );
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


    modifier requireExactFunding()
    {
        require(msg.value == FUNDING_AMOUNT, "Exact funding amount required" );
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

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (
                                address airlineAddress
                            )
                            external
    {
        if (nbrRegisteredAirlines < MIN_REGISTERED_AIRLINES_TO_VOTE) {
            //We are in the case where we do not have enough airlines to vote
            //So we just need to add its data to the collection and making it awaiting funding
            _registerAirlineData(airlineAddress, false, true);
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
                    returns(bool)
    {
        return airlines[ airlineAddress ].isRegistered;
    }


    function _registerAirlineData
                    (
                        address airlineAddress,
                        bool isRegistered,
                        bool awaitsFunding
                    )
                    private
    {
        AirlineData memory airlineData;
        if (!airlines[ airlineAddress ].exists) {
            airlineData = AirlineData( isRegistered, awaitsFunding, 0, true );
            airlines[ airlineAddress ] = airlineData;
        }
        else {
            airlines[ airlineAddress ].isRegistered = isRegistered;
        }
        
        //Increments the counter if the airline is registered
        if (isRegistered) {
            nbrRegisteredAirlines = SafeMath.add(nbrRegisteredAirlines, 1);
        }
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (                             
                            )
                            external
                            payable
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
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
    {
        //We make basic checks
        require( airlines[airlineAddress].exists, "Airline not yet registered" );
        require( !airlines[airlineAddress].isRegistered, "Airline already registered" );
        require( airlines[airlineAddress].awaitsFunding, "Airline must be awaiting funding" );

        //We update the airline to be mared as REGISTERED and not expecting funding anymore
        _registerAirlineData( airlineAddress, true, false );

        
        

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

