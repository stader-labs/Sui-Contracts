module suix::suix {
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Supply, Balance};
    use sui::staking_pool::{Delegation, StakedSui};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::sui_system::{Self, SuiSystemState};

    struct SUIX has drop {}

    /// For when supplied Coin is zero.
    const EZeroAmount: u64 = 0;

    /// Capability that grants an owner the right to collect SUI.
    struct OwnerCap has key { id: UID }

    struct Pool has key {
        id: UID,
        sui: Balance<SUI>,
        suix_supply: Supply<SUIX>,
        /// Fee Percent is denominated in basis points.
        fee_percent: u64
    }


    fun init(witness: SUIX, ctx: &mut TxContext) {
        
        transfer::transfer(OwnerCap {
            id: object::new(ctx)
        }, tx_context::sender(ctx));

        transfer::share_object(Pool {
            id: object::new(ctx),
            sui: balance::zero<SUI>(),
            suix_supply: balance::create_supply(witness),
            fee_percent: 0,
        });
    }

     /// Entrypoint for the `add_liquidity` method. Sends `SUIX` to
    /// the transaction sender.
    entry fun add_liquidity_(
        pool: &mut Pool, sui: Coin<SUI>, ctx: &mut TxContext
    ) {
        transfer::transfer(
            add_liquidity(pool, sui, ctx),
            tx_context::sender(ctx)
        );
    }

    /// add liquidity to the `Pool` by transder `SUIX`.
    /// Returns `SUIX`.
    public fun add_liquidity(
        pool: &mut Pool, sui: Coin<SUI>, ctx: &mut TxContext
    ): Coin<SUIX> {
        assert!(coin::value(&sui) > 0, EZeroAmount);

        let sui_balance = coin::into_balance(sui);


        let sui_added = balance::value(&sui_balance);
        let share_minted = sui_added;

        let balance = balance::increase_supply(&mut pool.suix_supply, share_minted);

        balance::join(&mut pool.sui, sui_balance);

        coin::from_balance(balance, ctx)
    }



    /// Entrypoint for the `remove_liquidity` method. Transfers
    /// withdrawn assets (SUI) to the sender.
    entry fun remove_liquidity_(
        pool: &mut Pool,
        suix: Coin<SUIX>,
        ctx: &mut TxContext
    ) {
        let (sui ) = remove_liquidity(pool, suix, ctx);
        let sender = tx_context::sender(ctx);

        transfer::transfer(sui, sender);
    }

    /// Remove liquidity from the `Pool` by burning `SUIX`.
    /// Returns `Coin<SUI>`.
    public fun remove_liquidity (
        pool: &mut Pool,
        suix: Coin<SUIX>,
        ctx: &mut TxContext
    ): Coin<SUI> {
        let suix_amount = coin::value(&suix);
        assert!(suix_amount > 0, EZeroAmount);

        let sui_removed = suix_amount;

        balance::decrease_supply(&mut pool.suix_supply, coin::into_balance(suix));

        coin::take(&mut pool.sui, sui_removed, ctx)
    }

    public fun remove_liquidity_and_undelegation(
        pool: &mut Pool,
        suix: Coin<SUIX>, 
        state: &mut SuiSystemState,
        delegation: &mut Delegation,
        staked_sui: &mut StakedSui,
        withdraw_pool_token_amount: u64,
        ctx: &mut TxContext,
    ) {
        balance::decrease_supply(&mut pool.suix_supply, coin::into_balance(suix));

        sui_system::request_withdraw_delegation(
            state, 
            delegation, 
            staked_sui,
            withdraw_pool_token_amount, 
            ctx
        );
    } 

    public fun add_liquidity_and_delegate(
        pool: &mut Pool, 
        sui: Coin<SUI>, 
        state: &mut SuiSystemState,
        validator_address: address,
        ctx: &mut TxContext

    ): Coin<SUIX> {
        assert!(coin::value(&sui) > 0, EZeroAmount);

        let sui_added = coin::value(&sui);
        let share_minted = sui_added;

        let balance = balance::increase_supply(&mut pool.suix_supply, share_minted);

        sui_system::request_add_delegation(state, sui, validator_address, ctx);
        coin::from_balance(balance, ctx)
    }

    /// Take coin from `Pool` and transfer it to tx sender.
    /// Requires authorization with `OwnerCap`.
    /// We will delegation from here
    public entry fun collect_sui(
        _: &OwnerCap, poll: &mut Pool, ctx: &mut TxContext
    ) {
        let amount = balance::value(&poll.sui);
        let profits = coin::take(&mut poll.sui, amount, ctx);

        transfer::transfer(profits, tx_context::sender(ctx))
    }


    /// Get most used values in a handy way:
    /// - amount of SUI
    /// - total supply of SUIX
    public fun get_amounts(pool: &Pool): (u64, u64) {
        (
            balance::value(&pool.sui),
            balance::supply_value(&pool.suix_supply)
        )
    }


    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(SUIX {}, ctx)
    }
}

#[test_only]
module suix::suix_tests {
    use sui::coin::{mint_for_testing as mint, destroy_for_testing as burn};
    use sui::test_scenario::{Self, Scenario, next_tx, ctx};
    use suix::suix::{Self, Pool, SUIX };
    use sui::sui_system::{SuiSystemState};
    use sui::sui::SUI;

   #[test] fun test_add_liquidity() { test_add_liquidity_( scenario()) }
   // TODO: FIX this test failed
//    #[test] fun test_delegation() { test_delegation_( scenario()) }
   #[test] fun test_remove_liquidity() { test_remove_liquidity_(scenario()) }


    use std::debug;
    fun test_init_pool_(scenario: &mut Scenario) {
        let (owner, _) = people();

        next_tx(scenario, owner); {
            suix::init_for_testing(ctx(scenario));
        };
        next_tx(scenario, VALIDATOR_ADDR_1); { 
            set_up_sui_system_state(scenario);
        };

        next_tx(scenario, owner); {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;
            let (amt_sui, suix_supply) = suix::get_amounts(pool_mut);

            assert!(suix_supply == 0, suix_supply);
            assert!(amt_sui == 0, 0);

            test_scenario::return_shared(pool)
        };
    }

    fun test_add_liquidity_(test:  Scenario) {
        let scenario = &mut test;

        test_init_pool_(scenario);

        let (_, theguy) = people();

        next_tx(scenario, theguy); {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;

            let suix_tokens = suix::add_liquidity(
                pool_mut,
                mint<SUI>(100, ctx(scenario)),
                ctx(scenario)
            );

            let (_, suix_supply) = suix::get_amounts(pool_mut);
            assert!(burn(suix_tokens) == suix_supply, 1);

            test_scenario::return_shared(pool)
        };
        test_scenario::end(test);
    }
    use sui::governance_test_utils::{
        create_validator_for_testing,
        create_sui_system_state_for_testing
    };

    use sui::object::{Self};
    use sui::tx_context::{Self};
    use sui::staking_pool::{Delegation};

    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;

    #[test_only]
    fun set_up_sui_system_state(scenario: &mut Scenario) {
        let ctx = test_scenario::ctx(scenario);

        let validators = vector[
            create_validator_for_testing(VALIDATOR_ADDR_1, 100, ctx),
            create_validator_for_testing(VALIDATOR_ADDR_2, 100, ctx)
        ];
        create_sui_system_state_for_testing(validators, 300, 100);
    }

    fun test_delegation_(test:  Scenario) {
        let scenario = &mut test;

        debug::print(&b"123");

        test_init_pool_(scenario);

        let (_, theguy) = people();
        next_tx(scenario, theguy); {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;


            let state = test_scenario::take_shared<SuiSystemState>(scenario);
            let state_mut = &mut state;

            let suix_tokens = suix::add_liquidity_and_delegate(
                pool_mut,
                mint<SUI>(100, ctx(scenario)),
                state_mut,
                VALIDATOR_ADDR_1,
                ctx(scenario)
            );

            let id1 = object::id_from_address(tx_context::last_created_object_id(ctx(scenario)));
            let obj1 = test_scenario::take_from_sender_by_id<Delegation>(scenario, id1);


            let (_, suix_supply) = suix::get_amounts(pool_mut);
            assert!(burn(suix_tokens) == suix_supply, 2);

            test_scenario::return_to_sender(scenario, obj1);
            test_scenario::return_shared(pool);
            test_scenario::return_shared(state);
        };
        test_scenario::end(test);
    }



    /// Expect SUIX tokens to double in supply when the same values passed
    fun test_remove_liquidity_(test: Scenario) {
        let scenario = &mut test;

        test_init_pool_(scenario);

        let (_, theguy) = people();

        next_tx(scenario, theguy); {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;

            let suix_tokens = suix::add_liquidity(
                pool_mut,
                mint<SUI>(100, ctx(scenario)),
                ctx(scenario)
            );

            let (_, suix_supply) = suix::get_amounts(pool_mut);
            assert!(burn(suix_tokens) == suix_supply, 1);

            test_scenario::return_shared(pool)
        };

        next_tx(scenario, theguy); {
            let pool = test_scenario::take_shared<Pool>(scenario);
            let pool_mut = &mut pool;

            let sui = suix::remove_liquidity(
                pool_mut,
                mint<SUIX>(100, ctx(scenario)),
                ctx(scenario)
            );

            let (_, suix_supply) = suix::get_amounts(pool_mut);
            assert!(0 == suix_supply, suix_supply);

            assert!(burn(sui) == 100, 1);
            test_scenario::return_shared(pool)
        };
        test_scenario::end(test);
    }

    // utilities
    fun scenario(): Scenario { test_scenario::begin(@0x1) }
    fun people(): (address, address) { (@0xBEEF, @0xA11CE) }
}