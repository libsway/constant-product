use fuels::prelude::*;

abigen!(
    ConstantProductAMM,
    "./amm/out/debug/ConstantProductPool-abi.json"
);

abigen!(
    MockToken,
    "./amm_tests/out/debug/amm_test-abi.json"
);

#[tokio::test]
async fn test_add_liquidity() {
    let wallet = launch_provider_and_get_wallet().await;

    let (tokenA, tokenA_id) = get_test_mock_token_instance(wallet).await;
    let (tokenB, tokenB_id) = get_test_mock_token_instance(wallet).await;

    let (amm, amm_id) = get_test_amm_instance(wallet).await;


}

async fn get_test_amm_instance(
    wallet: WalletUnlocked,
) -> (ConstantProductAMM, Bech32ContractId) {
    let id = Contract::deploy(
        "./amm/out/debug/ConstantProductPool.bin",
        &wallet,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "./amm/out/debug/ConstantProductPool-storage_slots.json"
                .to_string(),
        )),
    )
    .await
    .unwrap();

    let instance = ConstantProductAMM::new(id.to_string(), wallet);

    (instance, id)
}

async fn get_test_mock_token_instance(
    wallet: WalletUnlocked,
) -> (MockToken, Bech32ContractId) {
    let id = Contract::deploy(
        "./amm_test/out/debug/amm_test.bin",
        &wallet,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "./amm/out/debug/amm_test-storage_slots.json"
                .to_string(),
        )),
    )
    .await
    .unwrap();

    let instance = MockToken::new(id.to_string(), wallet);

    (instance, id)
}