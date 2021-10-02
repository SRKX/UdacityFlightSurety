import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.firstAirline = '0xf17f52151EbEF6C7334FAD080c5704D77216b732';
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress );
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress );
        this.appAddress = config.appAddress;
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            this.flightSuretyData.methods.authorizeCaller( this.appAddress ).send( { from: this.owner });

            callback();
        });
    }

    fundFirstAirline(callback) {
        let self = this;
        self.flightSuretyApp.methods.fundAirline()
            .send( {from: self.firstAirline, value: self.web3.utils.toWei( "10.0", "ether"), gas:9999999 }, callback );
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    getBalance(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .getBalance()
            .call( {from:self.owner}, callback)
    }

    withdraw(callback) {
        let self = this;
        self.flightSuretyApp.methods
            .withdraw()
            .send( {from:self.owner, gas:9999999}, callback)
    }

    fetchFlightStatus(flight,timestamp, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: timestamp
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }

    buyInsurance(flight, amount, timestamp, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: timestamp
        } 

                
        self.flightSuretyApp.methods
            .insureFlight(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner, value: self.web3.utils.toWei( amount, "ether"), gas:9999999}, (error, result) => {
                callback(error, payload);
            });       

        
    }
}