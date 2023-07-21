///////////////////////////////////////////////////////////////////
// 0L Module
// Genesis Migration
///////////////////////////////////////////////////////////////////
// This module is used in hard upgrade where a new genesis takes place, and which requires migrations.
// on the rust side, vm_geneses/lib.rs is used to call migrate_user function here below.

module ol_framework::genesis_migration {
  use std::signer;
  use std::error;
  use aptos_framework::coin;
  use ol_framework::ol_account;
  use ol_framework::validator_universe;
  use ol_framework::gas_coin;
  use ol_framework::gas_coin::GasCoin;
  use aptos_framework::system_addresses;
  // use aptos_std::debug::print;


  const EBALANCE_MISMATCH: u64 = 0;
  const EGENESIS_BALANCE_TOO_HIGH: u64 = 1;

  /// Called by root in genesis to initialize the GAS coin
  public fun migrate_legacy_user(
      vm: &signer,
      user_sig: &signer,
      auth_key: vector<u8>,
      expected_initial_balance: u64,
      // split_factor: u64, // precision of 1,000,000
  ) {
    system_addresses::assert_aptos_framework(vm);

    let user_addr = signer::address_of(user_sig);
    // if not a validator OR operator of a validator, create a new account
    // previously during genesis validator and oper accounts were already created
    if (!is_genesis_val(user_addr)) {
      ol_account::vm_create_account_migration(
        vm,
        user_addr,
        auth_key,
      );
    };

    // mint coins again to migrate balance, and all
    // system tracking of balances
    if (expected_initial_balance == 0) {
      return
    };

    // Genesis validators receive a minimal bootstrap mint, to do network operations. If the user has a balance to migrate, then the balance is net of this amount.
    let genesis_balance = coin::balance<GasCoin>(user_addr);

    // scale up by the coin split factor

    // let split_factor = fixed_point32::create_from_rational(split_factor, 1000000);
    // let expected_final_balance = fixed_point32::multiply_u64(legacy_balance, split_factor);

    // let expected_final_balance = (legacy_balance * split_factor) / 1000000;
    // print(&expected_final_balance);


    assert!(expected_initial_balance >= genesis_balance, error::invalid_state(EGENESIS_BALANCE_TOO_HIGH));

    let coins_to_mint = expected_initial_balance - genesis_balance;
    gas_coin::mint(vm, user_addr, coins_to_mint);

    let new_balance = coin::balance<GasCoin>(user_addr);

    assert!(new_balance == expected_initial_balance, error::invalid_state(EBALANCE_MISMATCH));
  }

  fun is_genesis_val(addr: address): bool {
    // TODO: other checks?
    validator_universe::is_in_universe(addr)
  }
}