contract;

use std::{
    block::timestamp,
    call_frames::contract_id,
    context::this_balance,
    contract_id::ContractId,
    identity::Identity,
    revert::require,
    token::{
        transfer,
        burn,
        mint_to,
    },
    u128::U128,
};

enum ConstantProductError {
    INSUFFICIENT_LIQUIDITY_MINTED: (),
    INSUFFICIENT_OUTPUT_AMOUNT: (),
    INVALID_TO: (),
    INSUFFICIENT_INPUT_AMOUNT: (),
    K: (),
    INSUFFICIENT_LIQUIDITY_BURNED: (),
}

abi ConstantProduct {
    #[storage(read)]
    fn token0() -> ContractId;
    #[storage(read)]
    fn token1() -> ContractId;
    #[storage(read)]
    fn get_reserves() -> (u64, u64, u32);
    #[storage(read)]
    fn price0_cumulative_last() -> U128;
    #[storage(read)]
    fn price1_cumulative_last() -> U128;
    #[storage(read)]
    fn k_last() -> U128;
    #[storage(read, write)]
    fn mint(to: Identity) -> U128;
    #[storage(read, write)]
    fn burn(to: Identity) -> (u64, u64);
    #[storage(read, write)]
    fn swap(amount0_out: u64, amount1_out: u64, to: Identity);
    #[storage(read, write)]
    fn sync();
    #[storage(write)]
    fn initialize(tokenA: ContractId, tokenB: ContractId);
}

storage {
    token0: ContractId = ContractId {
        value: 0x0000000000000000000000000000000000000000000000000000000000000000,
    },
    token1: ContractId = ContractId {
        value: 0x0000000000000000000000000000000000000000000000000000000000000000,
    },
    reserve0: u64 = 0,
    reserve1: u64 = 0,
    block_timestamp_last: u32 = 0,
    price0_cumulative_last: U128 = U128 {
        upper: 0,
        lower: 0,
    },
    price1_cumulative_last: U128 = U128 {
        upper: 0,
        lower: 0,
    },
    k_last: U128 = U128 {
        upper: 0,
        lower: 0,
    },
    total_supply: u64 = 0,
    fee_to: Identity = Identity::ContractId(ContractId {
        value: 0x0000000000000000000000000000000000000000000000000000000000000000,
    }),
}
impl ConstantProduct for Contract {
    #[storage(read)]
    fn token0() -> ContractId {
        storage.token0
    }
    #[storage(read)]
    fn token1() -> ContractId {
        storage.token1
    }
    #[storage(read)]
    fn get_reserves() -> (u64, u64, u32) {
        (
            storage.reserve0,
            storage.reserve1,
            storage.block_timestamp_last,
        )
    }
    #[storage(read)]
    fn price0_cumulative_last() -> U128 {
        storage.price0_cumulative_last
    }
    #[storage(read)]
    fn price1_cumulative_last() -> U128 {
        storage.price1_cumulative_last
    }
    #[storage(read)]
    fn k_last() -> U128 {
        storage.k_last
    }

    #[storage(read, write)]
    fn mint(to: Identity) -> U128 {
        let reserve0 = storage.reserve0;
        let reserve1 = storage.reserve1;
        let block_timestamp_last = storage.block_timestamp_last;

        let balance0 = this_balance(storage.token0);
        let balance1 = this_balance(storage.token1);

        let amount0 = balance0 - reserve0;
        let amount1 = balance1 - reserve1;
        let fee_on: bool = mint_fee(reserve0, reserve1);

        let _total_supply = U128 {
            upper: 0,
            lower: storage.total_supply,
        };

        let mut liquidity = U128 {
            upper: 0,
            lower: 0,
        };
        if _total_supply == (U128 {
            upper: 0,
            lower: 0,
        }) {
            liquidity = (U128 {
                upper: 0,
                lower: amount0,
            } * U128 {
                upper: 0,
                lower: amount1,
            }) - U128 {
                upper: 0,
                lower: 1000,
            };
            let zero_address = ContractId {
                value: 0x0000000000000000000000000000000000000000000000000000000000000000,
            };
            storage.total_supply = storage.total_supply + 1000; // 1000 is MINIMUM_LIQUIDITY here
            mint_to(1000, Identity::ContractId(zero_address)); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            let liquidity0: U128 = (U128 {
                upper: 0,
                lower: amount0,
            } * _total_supply) / U128 {
                upper: 0,
                lower: reserve0,
            };
            let liquidity1: U128 = (U128 {
                upper: 0,
                lower: amount1,
            } * _total_supply) / U128 {
                upper: 0,
                lower: reserve1,
            };

            if liquidity0 < liquidity1 {
                liquidity = liquidity0;
            } else {
                liquidity = liquidity1;
            }
        }

        require(liquidity == U128 {
            upper: 0,
            lower: 0,
        }, ConstantProductError::INSUFFICIENT_LIQUIDITY_MINTED);

        storage.total_supply = storage.total_supply + liquidity.lower;
        mint_to(liquidity.lower, to);
        _update(balance0, balance1, reserve0, reserve1);
        if fee_on {
            storage.k_last = U128 {
                upper: 0,
                lower: reserve0,
            } * U128 {
                upper: 0,
                lower: reserve1,
            };
        }
        liquidity
    }

    #[storage(read, write)]
    fn burn(to: Identity) -> (u64, u64) {
        let reserve0 = storage.reserve0;
        let reserve1 = storage.reserve1;

        let token0 = storage.token0;
        let token1 = storage.token1;

        let balance0 = this_balance(token0);
        let balance1 = this_balance(token1);

        let liquidity = U128 {
            upper: 0,
            lower: this_balance(contract_id()),
        };

        let fee_on = mint_fee(reserve0, reserve1);

        let _total_supply = U128 {
            upper: 0,
            lower: storage.total_supply,
        }; //
        let amount0 = (liquidity * U128 {
            upper: 0,
            lower: balance0,
        } / _total_supply).lower; // using balances ensures pro-rata distribution
        let amount1 = (liquidity * U128 {
            upper: 0,
            lower: balance1,
        } / _total_supply).lower; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, ConstantProductError::INSUFFICIENT_LIQUIDITY_BURNED);
        storage.total_supply = storage.total_supply - liquidity.lower;
        burn(liquidity.lower); // double check
        transfer(amount0, storage.token0, to);
        transfer(amount1, storage.token1, to);

        let balance0 = this_balance(token0);
        let balance1 = this_balance(token1);

        _update(balance0, balance1, reserve0, reserve1);
        if fee_on {
            storage.k_last = U128 {
                upper: 0,
                lower: reserve0,
            } * U128 {
                upper: 0,
                lower: reserve1,
            };
        }
        (amount0, amount1)
    }

    #[storage(read, write)]
    fn swap(amount0_out: u64, amount1_out: u64, to: Identity) {
        require(amount0_out > 0 || amount1_out > 0, ConstantProductError::INSUFFICIENT_OUTPUT_AMOUNT);
        let _reserve0 = storage.reserve0;
        let _reserve1 = storage.reserve1;

        let mut balance0: u64 = 0;
        let mut balance1: u64 = 0;

        require(to != Identity::ContractId(storage.token0) && to != Identity::ContractId(storage.token1), ConstantProductError::INVALID_TO);

        if (amount0_out > 0) {
            transfer(amount0_out, storage.token0, to);
        }
        if (amount1_out > 0) {
            transfer(amount1_out, storage.token1, to);
        }

        let balance0 = this_balance(storage.token0);
        let balance1 = this_balance(storage.token1);

        let mut amount0_in = 0;
        if balance0 > _reserve0 {
            amount0_in = balance0 - (_reserve0 - amount0_out);
        }
        let mut amount1_in = 0;
        if balance1 > _reserve0 {
            amount1_in = balance0 - (_reserve1 - amount1_out);
        }
        require(amount0_in > 0 || amount1_in > 0, ConstantProductError::INSUFFICIENT_INPUT_AMOUNT);

        let balance0_adjusted = U128 {
            upper: 0,
            lower: (balance0 * 1000) - (amount0_in * 3),
        };
        let balance1_adjusted = U128 {
            upper: 0,
            lower: (balance1 * 1000) - (amount1_in * 3),
        };

        let temp_k = ((U128 {
            upper: 0,
            lower: _reserve0,
        } * U128 {
            upper: 0,
            lower: 2000,
        }));

        require((balance0_adjusted * balance1_adjusted > temp_k) || (balance0_adjusted * balance1_adjusted == temp_k), ConstantProductError::K);

        _update(balance0, balance1, _reserve0, _reserve1);
    }

    #[storage(read, write)]
    fn sync() {
        let balance0 = this_balance(storage.token0);
        let balance1 = this_balance(storage.token1);
        _update(balance0, balance1, storage.reserve0, storage.reserve1);
    }

    #[storage(write)]
    fn initialize(tokenA: ContractId, tokenB: ContractId) {
        storage.token0 = tokenA;
        storage.token1 = tokenB;
    }
}

#[storage(read, write)]
fn _update(balance0: u64, balance1: u64, _reserve0: u64, _reserve1: u64) {
    // Overflow check is implicit vs UNI V2 because liquidity cannot overflow here
    let block_timestamp = timestamp() % (2 ** 32);
    let time_elapsed = block_timestamp - storage.block_timestamp_last; // check for weird overflow things here
    if time_elapsed > 0 && _reserve0 != 0 && _reserve1 != 0 {
        // * never overflows, and + overflow is desired
        storage.price0_cumulative_last = storage.price0_cumulative_last + ((U128 {
            upper: _reserve1,
            lower: 0,
        } / U128 {
            upper: 0,
            lower: _reserve0,
        }) * U128 {
            upper: 0,
            lower: time_elapsed,
        });
        storage.price1_cumulative_last = storage.price1_cumulative_last + ((U128 {
            upper: _reserve1,
            lower: 0,
        } / U128 {
            upper: 0,
            lower: _reserve0,
        }) * U128 {
            upper: 0,
            lower: time_elapsed,
        });
    }
    storage.reserve0 = balance0;
    storage.reserve1 = balance1;
    storage.block_timestamp_last = block_timestamp;
}

#[storage(read, write)]
fn mint_fee(reserve0: u64, reserve1: u64) -> bool {
    let fee_to = storage.fee_to;
    let k_last = storage.k_last;
    if k_last != (U128 {
        upper: 0,
        lower: 0,
    }) {
        let root_k = (U128 {
            upper: 0,
            lower: reserve0,
        } * U128 {
            upper: 0,
            lower: reserve1,
        }).sqrt();
        let root_k_last = k_last.sqrt();

        if root_k > root_k_last {
            let numerator = U128 {
                upper: 0,
                lower: storage.total_supply,
            } * (root_k - root_k_last);
            let denominator = (root_k * U128 {
                upper: 0,
                lower: 5,
            }) + root_k_last;

            let liquidity = (numerator / denominator).lower;

            if liquidity > 0 {
                storage.total_supply = storage.total_supply + liquidity;
                mint_to(liquidity, fee_to);
            }
        } else if k_last != (U128 {
            upper: 0,
            lower: 0,
        }) {
            storage.k_last = U128 {
                upper: 0,
                lower: 0,
            };
        }
    }
    true
}
