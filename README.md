# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.

## Packages used

Truffle v5.0.2 (core: 5.0.2)
Solidity - ^0.4.24 (solc-js)
Node v10.19.0

## Notes about testing of the project

JavaScript tests and DAPP/Oracle Server test should be run in parallel.

### Running JS test

It is advised to start a brand new version of ganache cli, using this bash script provided at the root of the project (it will use the default mnemomnic).

`> ./start_ganache_cli.sh`

then, the usual

`> npx truffle compile`

`> npx truffle migrate --reset`

and finally, running both tests separately.

`> npx truffle test ./test/flightSurety.js`

`> npx truffle test ./test/oracle.js`

**JS Tests - FlightSurety.js**

There are 9 tests being performed.

- The first 4 were provided by default and check that the contract can be switched on/off.
- Test 5 checks airline cannot participate until they are funded
- Test 6 shows airlines can participate once registered
- Test 7 shows the first few airlines do no need 50% consensus to accept a new airline
- Test 8 shows voting is required from the 5th airline onwards and demonstrates the voting mechanism works
- Test 9 shows a maximum of 1 ether can be bought for insurance on a given flight by a given address

**JS Tests - FlightSurety.js**

There are 2 tests performed.

- First one shows ability to register the oracles
- Second one illustrates indexes were indeed saved in the data contract.


### Running DAPP/Oracle Server Tests

It is advised to start a brand new version of ganache cli, using this bash script provided at the root of the project (it will use the default mnemomnic).

`> ./start_ganache_cli.sh`

then, the usual

`> npx truffle compile`

`> npx truffle migrate --reset`

and finally, starting up both apps.

`> npm run dapp`

`> npm run server`

For simplicity, we have test this demo using Ganache-CLI and hence, the account being used for the web3 called are hard-coded in Javascript.

First, it is important to click on the "Fund first airline" button, to make sure the contract has 10 ether to be able to payout insurees.

Then, buy some insurance by picking some options on the flights, and then inputting the amount (in ether) to be insured. Then, simply click on the "Buy Insurance" button. The app will fail if you try to insure of 1 ether, but will allow you to buy insurance by increment (0.5 ether, then again 0.5 ether, for example).

An interesting check at this point, is to click on the "Check my balance in contract" button, which should still be 0 because the oracles are yet to be summoned to give the status of the flight.

Finally, keep the same selection for flight and time, and click the "Submit to Oracles" button.

Upon startup, the oracles server has initiated 20 oracles which are listening to the events from the smart contracts. They have been coded to reply with the status code triggering an insurance payment 80% of the time, but will only reply if they have the right index. So you can be pretty sure any click will trigger a payment.

Now, click again on the "Check my balance in contract" button; you should now see you have been credited on your account *in the contract* by 1.5x what you insured.

You can now click on the "Withdraw to my wallet" button, which will transfer the funds from the data contract to your wallet directly.

Finally, a final check consist in clicking again on th "Check my balance in contract" to see that it has been reset to 0.

