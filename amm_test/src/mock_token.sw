contract;

use std::{
    token::mint_to,
    auth::msg_sender,
};

abi MockToken {
    #[storage(read, write)]
    fn faucet(amount: u64);
}

impl MockToken for Contract {
    #[storage(read, write)]
    fn faucet(amount: u64) {
        let sender: Identity = msg_sender().unwrap();
        mint_to(amount, sender);
    }
}