contract;

use std::{
    u128::U128,
    token::transfer,
    call_frames::contract_id,
    identity::Identity,
    contract_id::ContractId,
};

abi MockToken {
    #[storage(read, write)]
    fn faucet(amount: u64);
}

abi ConstantProductTest {
    #[storage(read, write)]
    fn initialize(token_a : b256, token_b: b256, amm: b256);
    #[storage(read, write)]
    fn test_mint() -> bool;
    #[storage(read, write)]
    fn test_burn() -> bool;
    #[storage(read, write)]
    fn test_swap() -> bool;
}

abi ContantProductPool {
    #[storage(read, write)]
    fn mint(to: Identity) -> U128;
    #[storage(read, write)]
    fn burn(to: Identity) -> (u64, u64);
    #[storage(read, write)]
    fn swap(amount0_out: u64, amount1_out: u64, to: Identity);
}

storage{
    token_a: b256 = 0x0000000000000000000000000000000000000000000000000000000000000000,
    token_b: b256 = 0x0000000000000000000000000000000000000000000000000000000000000000,

    amm: b256 = 0x0000000000000000000000000000000000000000000000000000000000000000,
}
impl ConstantProductTest for Contract {
    #[storage(read, write)]
    fn initialize(token_a : b256, token_b: b256, amm: b256) {
        storage.token_a = token_a;
        storage.token_b = token_b;

        storage.amm = amm;
    }

    #[storage(read, write)]
    fn test_mint() -> bool {
        let result = _add_liquidity();
        if result.lower > 0 {
            return true;
        }
        false
    }

    #[storage(read, write)]
    fn test_burn() -> bool {
        let liquidity = _add_liquidity();

        transfer(liquidity.lower, ContractId{value: storage.amm}, Identity::ContractId(ContractId{value: storage.amm}));

        let (amount0, amount1) = abi(ContantProductPool, storage.amm).burn(Identity::ContractId(contract_id()));
        if amount0 > 0 && amount1 > 1 {
            return true;
        }
        false
    }

    #[storage(read, write)]
    fn test_swap() -> bool {
        let _ = _add_liquidity();
        let token_a_contract = abi(MockToken, storage.token_a);
        token_a_contract.faucet(100000000);

        transfer(100000000, ContractId{value: storage.token_a}, Identity::ContractId(ContractId{value: storage.amm}));

        // Should revert if false
        abi(ContantProductPool, storage.amm).swap(0, 1000, Identity::ContractId(contract_id()));

        true
    }
}
fn _add_liquidity() -> U128 {
    let token_a_contract = abi(MockToken, storage.token_a);
    let token_b_contract = abi(MockToken, storage.token_b);
    token_a_contract.faucet(100000000);
    token_b_contract.faucet(100000000);

    transfer(100000000, ContractId{value: storage.token_a}, Identity::ContractId(ContractId{value: storage.amm}));
    transfer(100000000, ContractId{value: storage.token_b}, Identity::ContractId(ContractId{value: storage.amm}));

    let result = abi(ContantProductPool, storage.amm).mint(Identity::ContractId(contract_id()));

    result
}