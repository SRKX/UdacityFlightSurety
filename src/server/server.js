import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import { web } from 'webpack';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));

let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress );
//let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress );

// Watch contract events
const STATUS_CODE_UNKNOWN = 0;
const STATUS_CODE_ON_TIME = 10;
const STATUS_CODE_LATE_AIRLINE = 20;
const STATUS_CODE_LATE_WEATHER = 30;
const STATUS_CODE_LATE_TECHNICAL = 40;
const STATUS_CODE_LATE_OTHER = 50;

const NBR_ORACLES = 20;

//We get the available accounts
web3.eth.getAccounts().then( accounts => {
  //Which we first log
  console.log( "Accounts:"+accounts)
  //Then, we register the 20 oracles as the first 20 accounts
  for(let a=0; a<NBR_ORACLES; a++) {      
    //Note that we are re-using the code provided in the test oracles
    console.log( "Trying to register account " + accounts[a] )
    flightSuretyApp.methods.registerOracle().send({ from: accounts[a], value: web3.utils.toWei( "1", "ether"), gas:9999999 }).then( ()=> {
      flightSuretyApp.methods.getMyIndexes().call({from: accounts[a]}).then( (result) => {
        console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
      }).catch( error => console.log );
    })

  }
});



flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) {
      console.log("Error emitted!")
      console.log(error)
    }
    else {
      console.log("Event emitted!")
      console.log("Received event for %s, %s, %s, %s", event.returnValues.index, event.returnValues.airline, event.returnValues.flight, event.returnValues.timestamp );

      web3.eth.getAccounts().then( accounts => {
        for ( let a=0;a<NBR_ORACLES;a++) {
          flightSuretyApp.methods.getMyIndexes().call({ from: accounts[a]}).then( oracleIndexes => {
            //console.log( "Inidices for %s: %s", accounts[a], oracleIndexes)
            //We know there are 3 inidices by orcale
            for(let idx=0;idx<3;idx++) {

              try {
                // Submit a response...it will only be accepted if there is an Index match
                  
                  let researchedIndex = parseInt( event.returnValues.index );
                  if (researchedIndex == oracleIndexes[idx])
                  {

                    console.log( "Account %s will attempt to reply", accounts[a] )
                    
                    flightSuretyApp.methods.submitOracleResponse(
                      oracleIndexes[idx],
                      event.returnValues.airline,
                      event.returnValues.flight,
                      parseInt( event.returnValues.timestamp ),
                      STATUS_CODE_LATE_AIRLINE)
                      .send( { from: accounts[a], gas:9999999}
                      ).then( () => {
                        console.log( "Success" );
                        //console.log('\nSuccess', idx, oracleIndexes[idx], event.returnValues.flight, parseInt( event.returnValues.timestamp ));
                      }).catch( error => {
                        console.log( "Error")
                        //console.log( "An error occured when submitting oracle response", idx,  oracleIndexes[idx].toNumber(), flight, timestamp )
                        //console.log( error )
                      })
                  } 
              

              }
              catch(e) {
                // Enable this when debugging
                //console.log( "Error details: "+e);
              }
            }
          })

        }

      })

      

    }
});

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


