
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });


        // User-submitted transaction
        DOM.elid('fund-airline').addEventListener('click', () => {
            
            // Write transaction
            contract.fundFirstAirline((error, result) => {
                display('Airline funding', 'fund first airline', [ { label: 'Funded', error: error, value: result} ]);
            });
        })
    

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            let timestamp = parseInt( DOM.elid('flight-time').value );
            // Write transaction
            contract.fetchFlightStatus(flight, timestamp, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })

        DOM.elid('buy-insurance').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            let amount = DOM.elid('insure-amount').value;
            let timestamp = parseInt( DOM.elid('flight-time').value );
            // Write transaction
            contract.buyInsurance(flight, amount,timestamp,(error, result) => {
                display('Insurance', 'Bought insurance', [ { label: 'Result', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        });

        DOM.elid('get-current-balance').addEventListener('click', () => {
            // Write transaction
            contract.getBalance((error, result) => {
                display('Balance', 'Current balance', [ { label: 'Result', error: error, value: result} ]);
            });
        })

        DOM.elid('withdraw-balance').addEventListener('click', () => {
            // Write transaction
            contract.withdraw((error, result) => {
                display('Balance', 'Withdraw', [ { label: 'Result', error: error, value: result} ]);
            });
        })
    
    });
    

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}







