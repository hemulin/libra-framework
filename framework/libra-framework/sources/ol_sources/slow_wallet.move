//////// SLOW WALLETS ////////
// Slow wallets have a limited amount available to transfer between accounts.
// Using Coins for network operations has no limit. Sending funds to DonorDirected wallets is also unlimited. Coins are free and clear user's property.
// Every epoch a new amount is made available (unlocked)
// slow wallets can use the normal payment and transfer mechanisms to move
// the unlocked amount.

module ol_framework::slow_wallet {
  use diem_framework::system_addresses;
  // use diem_framework::coin;
  use std::vector;
  use std::signer;
  // use ol_framework::gas_coin::T;
  use ol_framework::testnet;
  use std::error;

  // use diem_std::debug::print;

  friend ol_framework::ol_account;
  friend diem_framework::coin;

  /// genesis failed to initialized the slow wallet registry
  const EGENESIS_ERROR: u64 = 1;

  const EPOCH_DRIP_CONST: u64 = 100000;

    struct SlowWallet<phantom CoinType> has key {
        unlocked: u64,
        transferred: u64,
    }

    struct SlowWalletList<phantom CoinType> has key {
        list: vector<address>
    }

    public fun initialize<T>(vm: &signer){
      system_addresses::assert_ol(vm);
      if (!exists<SlowWalletList<T>>(@ol_framework)) {
        move_to<SlowWalletList<T>>(vm, SlowWalletList {
          list: vector::empty<address>()
        });
      }
    }

    /// private function which can only be called at genesis
    /// must apply the coin split factor.
    // TODO: make this private with a public test helper
    public fun fork_migrate_slow_wallet<T>(
      vm: &signer,
      user: &signer,
      unlocked: u64,
      transferred: u64,
      // split_factor: u64,
    ) acquires SlowWallet, SlowWalletList {
      system_addresses::assert_ol(vm);

      let user_addr = signer::address_of(user);
      if (!exists<SlowWallet<T>>(user_addr)) {
        move_to<SlowWallet<T>>(user, SlowWallet {
          unlocked,
          transferred,
        });

        update_slow_list<T>(vm, user);
      } else {
        let state = borrow_global_mut<SlowWallet<T>>(user_addr);
        state.unlocked = unlocked;
        state.transferred = transferred;
      }
    }

    /// private function which can only be called at genesis
    /// sets the list of accounts that are slow wallets.
    fun update_slow_list<T>(
      vm: &signer,
      user: &signer,
    ) acquires SlowWalletList{
      system_addresses::assert_ol(vm);
      if (!exists<SlowWalletList<T>>(@ol_framework)) {
        initialize<T>(vm); //don't abort
      };
      let state = borrow_global_mut<SlowWalletList<T>>(@ol_framework);
      let addr = signer::address_of(user);
      if (!vector::contains(&state.list, &addr)) {
        vector::push_back(&mut state.list, addr);
      }
    }

    public fun set_slow<T>(sig: &signer, coin_balance: u64) acquires SlowWalletList {
      assert!(exists<SlowWalletList<T>>(@ol_framework), error::invalid_argument(EGENESIS_ERROR));

        let addr = signer::address_of(sig);
        let list = get_slow_list<T>();
        if (!vector::contains<address>(&list, &addr)) {
            let s = borrow_global_mut<SlowWalletList<T>>(@ol_framework);
            vector::push_back(&mut s.list, addr);
        };

        if (!exists<SlowWallet<T>>(signer::address_of(sig))) {
          move_to<SlowWallet<T>>(sig, SlowWallet {
            unlocked: coin_balance,
            transferred: 0,
          });
        }
    }

    public fun slow_wallet_epoch_drip<T>(vm: &signer, amount: u64) acquires SlowWallet, SlowWalletList{
      system_addresses::assert_ol(vm);
      let list = get_slow_list<T>();
      let i = 0;
      while (i < vector::length<address>(&list)) {
        let addr = vector::borrow<address>(&list, i);
        // let total = coin::balance<T>(*addr);
        let state = borrow_global_mut<SlowWallet<T>>(*addr);
        let next_unlock = state.unlocked + amount;
        state.unlocked = next_unlock;
        i = i + 1;
      }
    }

    /// wrapper to both attempt to adjust the slow wallet tracker
    /// on the sender and recipient.
    /// if either account is not a slow wallet no tracking
    /// will happen on that account.
    /// Sould never abort.
    public(friend) fun maybe_track_slow_transfer<T>(payer: address, recipient: address, amount: u64) acquires SlowWallet {
      maybe_track_unlocked_withdraw<T>(payer, amount);
      maybe_track_unlocked_deposit<T>(recipient, amount);
    }
    /// if a user spends/transfers unlocked coins we need to track that spend
    public(friend) fun maybe_track_unlocked_withdraw<T>(payer: address, amount: u64) acquires SlowWallet {
      if (!exists<SlowWallet<T>>(payer)) return;
      let s = borrow_global_mut<SlowWallet<T>>(payer);

      s.transferred = s.transferred + amount;
      s.unlocked = s.unlocked - amount;
    }

    /// when a user receives unlocked coins from another user, those coins
    /// always remain unlocked.
    public(friend) fun maybe_track_unlocked_deposit<T>(recipient: address, amount: u64) acquires SlowWallet {
      if (!exists<SlowWallet<T>>(recipient)) return;
      let state = borrow_global_mut<SlowWallet<T>>(recipient);

      // TODO:
      // unlocked amount cannot be greater than total
      // this will not halt, since it's the VM that may call this.
      // but downstream code needs to check this
      state.unlocked = state.unlocked + amount;
    }

    public fun on_new_epoch<T>(vm: &signer) acquires SlowWallet, SlowWalletList {
      system_addresses::assert_ol(vm);
      slow_wallet_epoch_drip<T>(vm, EPOCH_DRIP_CONST);
    }

    ///////// SLOW GETTERS ////////

    #[view]
    public fun is_slow<T>(addr: address): bool {
      exists<SlowWallet<T>>(addr)
    }

    // #[view]
    // /// helper to get the unlocked and total balance. (unlocked, total)
    // public fun balance<T>(addr: address): (u64, u64) acquires SlowWallet{
    //   // this is a normal account, so return the normal balance
    //   let total = coin::balance<T>(addr);
    //   if (exists<SlowWallet<T>>(addr)) {
    //     let s = borrow_global<SlowWallet<T>>(addr);
    //     return (s.unlocked, total)
    //   };

    //   // if the account has no SlowWallet tracker, then everything is unlocked.
    //   (total, total)
    // }

    // #[view]
    // // TODO: Deprecate this function in favor of `balance`
    // /// Returns the amount of unlocked funds for a slow wallet.
    // public fun unlocked_amount<T>(addr: address): u64 acquires SlowWallet{
    //   // this is a normal account, so return the normal balance
    //   if (exists<SlowWallet<T>>(addr)) {
    //     let s = borrow_global<SlowWallet<T>>(addr);
    //     return s.unlocked
    //   };

    //   coin::balance<T>(addr)
    // }

    #[view]
    // Getter for retrieving the list of slow wallets.
    public fun get_slow_list<T>(): vector<address> acquires SlowWalletList{
      if (exists<SlowWalletList<T>>(@ol_framework)) {
        let s = borrow_global<SlowWalletList<T>>(@ol_framework);
        return *&s.list
      } else {
        return vector::empty<address>()
      }
    }

    ////////// SMOKE TEST HELPERS //////////
    // cannot use the #[test_only] attribute
    public entry fun smoke_test_vm_unlock<T>(
      smoke_test_core_resource: &signer,
      user_addr: address,
      unlocked: u64,
      transferred: u64,
    ) acquires SlowWallet {

      system_addresses::assert_core_resource(smoke_test_core_resource);
      testnet::assert_testnet(smoke_test_core_resource);
      let state = borrow_global_mut<SlowWallet<T>>(user_addr);
      state.unlocked = unlocked;
      state.transferred = transferred;
    }
}
