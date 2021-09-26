
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);
    //await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
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

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {
        //We indeed generated an error
        errorThrown = true;
    }

    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(errorThrown, false, "Error thrown during registration attempt");
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) becomes registered after funding', async () => {
    
    // ARRANGE
    let firstAirline = config.firstAirline;
    let faBalanceBefore = await web3.eth.getBalance(firstAirline);
    console.log( "FA Balance Before: "+faBalanceBefore)

    let registeredBefore = await config.flightSuretyData.isAirline.call(firstAirline); 

    // ACT
    try {
        await config.flightSuretyApp.fundAirline( {from: config.firstAirline, value: web3.utils.toWei("10", "ether")  });
    }
    catch(e) {
        console.log( "An error was thrown: " + e);
    }

    let faBalanceAfter = await web3.eth.getBalance(firstAirline);
    console.log( "FA Balance after: "+faBalanceAfter)
    let result = await config.flightSuretyData.isAirline.call(firstAirline); 

    // ASSERT
    assert.equal(registeredBefore, false, "Airline should not yet be registered" );
    assert.equal(result, true, "Airline should not be able to register another airline if it hasn't provided funding");
    assert.isBelow( Number(faBalanceAfter), Number(faBalanceBefore), "Balance of first airline should have decreased")

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


      assert.equal( errorThrown, false, "Registered airline does not throw exception");
      assert.isFalse( sndAirlineRegBeforeFunded, "Second airline should not be registered before funding");
      assert.isTrue( sndAirlineRegAfterFunded, "Second airline should be registered after funding" )

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



        assert.equal( errorThrown, false, "Registered airline does not throw exception");
        assert.isFalse( sndAirlineRegBeforeFunded, "Second airline should not be registered before funding");
        assert.isTrue( sndAirlineRegAfterFunded, "Second airline should be registered after funding" )

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
         
  
        assert.isTrue( errorThrown, "5th airline cannot directly fund because it lacks votes");
        //assert.isFalse( sndAirlineRegBeforeFunded, "Second airline should not be registered before funding");
        //assert.isTrue( sndAirlineRegAfterFunded, "Second airline should be registered after funding" )
  
     }); 

});
