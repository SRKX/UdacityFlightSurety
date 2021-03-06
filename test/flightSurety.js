
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];
    let errorThrown = false;

    //let firstAirlineReg = await config.flightSuretyData.isAirline.call(config.firstAirline); 
    //console.log( "First airline registered: "+firstAirlineReg);


    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
        //errorThrown=true;
    }
    catch(e) {
        //We indeed generated an error
        console.log( "Error thrown:" + e)
        errorThrown = true;
    }

    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    let nbrAirlines = await config.flightSuretyData.getNumberOfRegisteredAirlines.call();

    // ASSERT
    assert.isTrue(errorThrown, "Error thrown during registration attempt");
    assert.isFalse(result, "Airline should not be able to register another airline if it hasn't provided funding");
    assert.equal(nbrAirlines, 0, "There are no airlines currently considered as registered");

  });

  it('(airline) becomes registered after funding', async () => {
    
    // ARRANGE
    let firstAirline = config.firstAirline;
    let faBalanceBefore = await web3.eth.getBalance(firstAirline);
    let dcBalanceBefore = await web3.eth.getBalance(config.flightSuretyData.address);
    //console.log( "FA Balance Before: "+faBalanceBefore)

    let registeredBefore = await config.flightSuretyData.isAirline.call(firstAirline); 

    // ACT
    try {
        console.log( "Trying to fund")
        await config.flightSuretyApp.fundAirline( {from: config.firstAirline, value: web3.utils.toWei("10", "ether"), nonce: await web3.eth.getTransactionCount(config.firstAirline)  });
        console.log( "Funding successful")
    }
    catch(e) {
        console.log( "An error was thrown: " + e);
    }

    let faBalanceAfter = await web3.eth.getBalance(firstAirline);
    let dcBalanceAfter = await web3.eth.getBalance(config.flightSuretyData.address);
    //console.log( "FA Balance after: "+faBalanceAfter)
    let result = await config.flightSuretyData.isAirline.call(firstAirline); 

    let nbrAirlines = await config.flightSuretyData.getNumberOfRegisteredAirlines.call();
    

    // ASSERT
    assert.equal(registeredBefore, false, "Airline should not yet be registered" );
    assert.equal(result, true, "Airline should not be able to register another airline if it hasn't provided funding");
    assert.isBelow( Number(faBalanceAfter), Number(faBalanceBefore), "Balance of first airline should have decreased")
    assert.isAbove( Number(dcBalanceAfter), Number(dcBalanceBefore), "Balance of the data contract should have increased")
    assert.equal(nbrAirlines, 1, "There should now be 1 registered airline");

  });

  it('(airline) registered airline can register new airlines without vote, but they sill require funding', async () => {

      let errorThrown = false;
      //We ask the first airline which is now registered to succest a second
      try {
        await config.flightSuretyApp.registerAirline(config.secondAirline, {from: config.firstAirline});
      }
      catch(e) {
        //We indeed generated an error
        errorThrown = true;
      }
      
      //Now, we still need the second airline not to be considered as registered until she is funded
      let sndAirlineRegBeforeFunded = await config.flightSuretyData.isAirline.call(config.secondAirline); 

      //Now, the second airline funds its participation to the contract
      await config.flightSuretyApp.fundAirline( {from: config.secondAirline, value: web3.utils.toWei("10", "ether")  });

      //After funding, we chek if it is registered
      let sndAirlineRegAfterFunded = await config.flightSuretyData.isAirline.call(config.secondAirline); 

      let nbrAirlines = await config.flightSuretyData.getNumberOfRegisteredAirlines.call();

      assert.equal( errorThrown, false, "Registered airline does not throw exception");
      assert.isFalse( sndAirlineRegBeforeFunded, "Second airline should not be registered before funding");
      assert.isTrue( sndAirlineRegAfterFunded, "Second airline should be registered after funding" )
      assert.equal( nbrAirlines, 2, "There are now 2 airlines registered")

   });

    it('(airline) 50% consensus is required for the 5th airline ', async () => {

        //We add 3rd and 4th airlines, and they submit their fund
        await config.flightSuretyApp.registerAirline(config.thirdAirline, {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(config.fourthAirline, {from: config.secondAirline});

        await config.flightSuretyApp.fundAirline( {from: config.thirdAirline, value: web3.utils.toWei("10", "ether")  });
        await config.flightSuretyApp.fundAirline( {from: config.fourthAirline, value: web3.utils.toWei("10", "ether")  });


        //Now, we add a fifth airline
        await config.flightSuretyApp.registerAirline(config.fifthAirline, {from: config.fourthAirline});

        let errorThrown = false;
        try {
            await config.flightSuretyApp.fundAirline( {from: config.fifthAirline, value: web3.utils.toWei("10", "ether")  });
        }
        catch(e) {
            errorThrown = true
            console.log( "An error was thrown: " + e);
        }

        let nbrAirlines = await config.flightSuretyData.getNumberOfRegisteredAirlines.call();
        console.log( "Nbr Airlines:" +nbrAirlines)

        //We know that there are 4 registered airlines,
        //so if we add a second vote, it should work

        //Let's first ensure the same airline cannot vote many time
        let errorThrownOnDuplicateVote = false;
        try {
            await config.flightSuretyApp.registerAirline(config.fifthAirline, {from: config.fourthAirline });
        }
        catch(e) {
            errorThrownOnDuplicateVote = true;
            console.log( "An error was thrown: " + e);
        }

        //Let's now have another airline voting
        await config.flightSuretyApp.registerAirline(config.fifthAirline, {from: config.secondAirline});
        console.log( "New vote sent ");



        //Fifth airline should now be able to send its fund
        //but not yet be considered as registered
        let fftAirlineRegBeforeFunded = await config.flightSuretyData.isAirline.call(config.fifthAirline); 
        console.log( "Is registered?"+fftAirlineRegBeforeFunded);
        await config.flightSuretyApp.fundAirline( {from: config.fifthAirline, value: web3.utils.toWei("10", "ether"),nonce: await web3.eth.getTransactionCount(config.fifthAirline)  });
        console.log( "Fifth Airline has funded");

        //And should now be registered
        let fftAirlineRegAfterFunded = await config.flightSuretyData.isAirline.call(config.fifthAirline); 

         
        assert.isTrue( errorThrown, "5th airline cannot directly fund because it lacks votes");
        assert.isTrue( errorThrownOnDuplicateVote, "Airline cannot vote twice for same candidate");
        assert.isFalse( fftAirlineRegBeforeFunded, "Second airline should not be registered before funding");
        assert.isTrue( fftAirlineRegAfterFunded, "Second airline should be registered after funding" )
  
     });

     it( "flight can be insured for a maximum of 1 ether", async ()  => {
        let flight = 'ND1309'; // Course number
        let flight2 = 'LX1234';
        let timestamp = Math.floor(Date.now() / 1000);


        let exceptionThrown = false;
        try {
            //This should fail  because there is too much insured
            await config.flightSuretyApp.insureFlight( config.firstAirline,
                                    flight,
                                    timestamp,
                                    {
                                        from:config.passengerAccount,
                                        value: web3.utils.toWei( "1.5", "ether")
                                    } );
        }
        catch(e) {
            exceptionThrown = true;
            console.log( "An error was thrown: " + e);
        }



        let exceptionThrown2 = false;
        
        let paBalanceBefore = await web3.eth.getBalance(config.passengerAccount);

        try {
            await config.flightSuretyApp.insureFlight( config.firstAirline,
                                    flight,
                                    timestamp,
                                    {
                                        from:config.passengerAccount,
                                        value: web3.utils.toWei( "0.5", "ether"),
                                        nonce: await web3.eth.getTransactionCount(config.passengerAccount)
                                    } );
        }
        catch(e) {
            exceptionThrown2 = true;
        }
        
        let insuredAmount = await config.flightSuretyApp.getInsuredAmount.call(
            config.firstAirline,
            flight,
            timestamp,
            {
                from:config.passengerAccount,
                nonce: await web3.eth.getTransactionCount(config.passengerAccount)
            });


        let paBalanceAfter = await web3.eth.getBalance(config.passengerAccount);

        let exceptionThrown3 = false;

        try {
            await config.flightSuretyApp.insureFlight( config.firstAirline,
                                    flight,
                                    timestamp,
                                    {
                                        from:config.passengerAccount,
                                        value: web3.utils.toWei( "0.75", "ether"),
                                        nonce: await web3.eth.getTransactionCount(config.passengerAccount)
                                    } );
        }
        catch(e) {
            exceptionThrown3 = true;
            console.log( "An error was thrown: " + e);
        }


        let exceptionThrown4 = false;
        try {
            await config.flightSuretyApp.insureFlight( config.firstAirline,
                                    flight,
                                    timestamp,
                                    {
                                        from:config.passengerAccount,
                                        value: web3.utils.toWei( "0.5", "ether"),
                                        nonce: await web3.eth.getTransactionCount(config.passengerAccount)
                                    } );
        }
        catch(e) {
            exceptionThrown4 = true;
        }

        let insuredAmount2 = await config.flightSuretyApp.getInsuredAmount.call(
                        config.firstAirline,
                        flight,
                        timestamp,
                        {
                            from:config.passengerAccount,
                            nonce: await web3.eth.getTransactionCount(config.passengerAccount)
                        }

                    );

        console.log( "Insured amount: %d", insuredAmount2 );

        assert.isTrue( exceptionThrown, "No exception was thrown for an invalid amount")
        assert.isFalse( exceptionThrown2, "An exception was thrown during a valid registration attempt")
        assert.isTrue( exceptionThrown3, "No exception thrown after oversize top-up")
        assert.isFalse( exceptionThrown4, "An exception was thrown during a valid top-up")
        assert.isBelow( Number(paBalanceAfter), Number(paBalanceBefore), "Amount not deducted from passenger")
        assert.equal( insuredAmount, web3.utils.toWei("0.5", "ether"), "Incorrect insured amount after initial insurance");
        assert.equal( insuredAmount2, web3.utils.toWei("1.0", "ether"), "Incorrect insured amount after top-up");

        

     });

     

});
