pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    //Properties used for Arilines consensus
    uint private constant MIN_REGISTERED_AIRLINES_TO_VOTE = 4; //When do we start needing requiring votes?
    mapping( address => address[] ) private currentVotes; //Mapping for votes

    FlightSuretyDataInterface private dataContract;

    uint private constant MAXIMUM_INSURED_AMOUNT = 1 ether;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

 
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
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
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

    //Ensures the caller is actually a registered airline
    modifier requireRegisteredAirline()
    {
        require( dataContract.isAirline( msg.sender ), "Caller of the contract is not a registered airline!" );
        _;
    }

    modifier requireValidAmount()
    {
        require( msg.value <= MAXIMUM_INSURED_AMOUNT, "Amount to be insureed to big.");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address dataAddress
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        //Initializes the data contract address
        dataContract = FlightSuretyDataInterface( dataAddress );
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        //Calls corresponding method in the data contract
        return dataContract.isOperational();
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline
                            (
                                address airlineAddress
                            )
                            public
                            requireRegisteredAirline
                            returns(bool, uint)
    {

        //require( dataContract.isAirline(msg.sender), "Somethign is wrong");

        //By default, the total number of votes is 0
        uint airlineVotes = 0;
        bool success = false;

        if (dataContract.getNumberOfRegisteredAirlines() < MIN_REGISTERED_AIRLINES_TO_VOTE) {
            //We are in the case where we do not have enough airlines to vote
            //So we just need to add its data to the collection and making it awaiting funding
            dataContract.registerAirline(airlineAddress, false, true);
            success = true;
        }
        else {
            //We need to vote, and this operation is considered as a vote.
            //The votes are counted using a list of addresses
            //First, we get the list of current votes
            address[] storage votes = currentVotes[ airlineAddress ];

            bool hasVoted = false;

            //We loop through the voting mechanism to ensure this airline has not already voted
            for (uint i=0; i<votes.length; i++) {
                if (votes[i]==msg.sender) {
                    hasVoted = true;
                    break;
                }
            }

            //We fail if the registerer is trying to vote again
            require( !hasVoted, "Airline cannot vote twice for the same candidate" );

            //Otherwise, we add the current address to list 
            currentVotes[ airlineAddress ].push( msg.sender );

            //The current number of votes is simply the lenght of the votes list
            airlineVotes = currentVotes[ airlineAddress ].length;


            if (airlineVotes >= requiredVotes()) {
                //The airline can now be considered registered as "AWAITING FUNDING"
                dataContract.registerAirline(airlineAddress, false, true);
                success = true;
            }
            else {
                //The airline sill needs more votes so we simply leave it as it is
                dataContract.registerAirline(airlineAddress, false, false);
            }

        }

        return (success, airlineVotes);
    }

    /*
     * Simple function returning the required number of votes
     */
    function requiredVotes() public view returns(uint)
    {
        return SafeMath.div( dataContract.getNumberOfRegisteredAirlines(), 2 );
    }



    function fundAirline
                        (
                        )
                        public
                        payable
    {
        require( msg.value >= 10 ether, "Not enough ether was provided" );
        dataContract.fund.value(10 ether )( msg.sender );
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
                                (
                                )
                                external
                                pure
    {
        

    }

    function insureFlight
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        public
                        payable
                        requireValidAmount
    {
        //We compute the flight key
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        //We build the key to get a possible already registered amount
        bytes32 amountKey = getAmountKey( flightKey, msg.sender );
        //We get the amount (will return 0 if non-existent)
        uint insuredAmount = dataContract.getInsuredAmount( amountKey );
        //We check the value does not exceed
        require(insuredAmount + msg.value <= MAXIMUM_INSURED_AMOUNT, "Insured amount is too big");
        //We send the amount to the data contract
        dataContract.buy.value(msg.value)(msg.sender, amountKey, flightKey);
        


    }
    

    /*
     * Allows a speicific user to show how much he has insured a flight for.
     */
    function getInsuredAmount(address airline,
                            string memory flight,
                            uint256 timestamp)
                            public view
                            returns(uint)
    {
        //We compute the flight key
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        //We build the key to get a possible already registered amount
        bytes32 amountKey = getAmountKey( flightKey, msg.sender );

        return dataContract.getInsuredAmount( amountKey );

    }


    /*
     * Allows sender to see how much ether he has available
     */
    function getBalance()
                public view
                returns(uint)
    {
        return dataContract.getBalance(msg.sender);
    }

    function withdraw()
            public
    {
        //Simply asks the data contract to pay whatever is available.
        dataContract.pay(msg.sender);
    }
    
   /**
    * @dev Called after oracle has updated flight status
    * 
    */  
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
    {
        //We first tell the data contract to update the status of the flight
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        require( dataContract.getFlightStatus(flightKey) == STATUS_CODE_UNKNOWN, "Flight status has already been set!" );

        dataContract.updateFlightStatus(flightKey, statusCode);

        //We check if the flight was delayed because of the airline
        if (statusCode == STATUS_CODE_LATE_AIRLINE) {
            //In this case, we retrieve all clients who had bought an insurance for the given flight
            address[] memory insurees = dataContract.getFlightInsurees(flightKey);
            //Credit their account in the data contract
            for (uint i=0; i<insurees.length; i++) {
                //We build the key
                bytes32 amountKey = getAmountKey( flightKey, insurees[i] );
                //We get the amount
                uint insuredAmount = dataContract.getInsuredAmount( amountKey );
                //Amount to credit is computed by multiplying by 3 and dividing by 2
                //which is the integer equivalent of multiplying by 1.5
                uint amountToCredit = SafeMath.div( SafeMath.mul(insuredAmount, 3), 2);
                //We credit the account of the insuree
                dataContract.creditInsurees(insurees[i], amountToCredit);
            }
        }



    }


    /*
     * Generates hash key for insured amount by combining the flight hash key
     * and the insuree address
     */
    function getAmountKey
                        (
                            bytes32 flightKey,
                            address insuree
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(flightKey, insuree));
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string flight,
                            uint256 timestamp                            
                        )
                        public
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            public
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        public
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request, or responses is closed");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);

            //We need to close the request now
            oracleResponses[key].isOpen = false;
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   

//Contract interface for Data contract
contract FlightSuretyDataInterface {
    function isOperational() 
                            public
                            view
                            returns(bool);

    function registerAirline
                            (
                                address airlineAddress,
                                bool isRegistered,
                                bool awaitsFunding
                            )
                            public;

    function getNumberOfRegisteredAirlines() external view returns(uint);

    function isAirline
                    (
                        address airlineAddress
                    )
                    public
                    view
                    returns(bool);

    function fund
                (
                    address airlineAddress   
                )
                public
                payable;

    function getFlightStatus( bytes32 flightKey )
                external
                view
                returns(uint8);


    function updateFlightStatus
                (
                    bytes32 flightKey,
                    uint8 statusCode
                ) external;

    function getFlightInsurees( bytes32 flightKey )
                    external view returns( address[] );

    function getInsuredAmount( bytes32 insuredAmountKey )
                external view returns( uint );

    function creditInsurees
                    (
                        address insureeAddress,
                        uint amount
                    )
                    external;

    function getBalance( address insureeAddress ) 
                external
                view
                returns(uint);


    function buy
                (
                    address insureeAddress,
                    bytes32 amountKey,
                    bytes32 flightKey     
                )
                external
                payable;
    
    function pay
            (
                address insureeAddress
            )
            external;
}