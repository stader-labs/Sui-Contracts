module suix::suix {
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Supply, Balance};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::sui_system::{Self, SuiSystemState };
    use sui::delegation::Delegation;
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

        // If there's a non-empty LSP, we can
        assert!(suix_amount > 0, EZeroAmount);

        let sui_removed = suix_amount;

        balance::decrease_supply(&mut pool.suix_supply, coin::into_balance(suix));

        coin::take(&mut pool.sui, sui_removed, ctx)
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

    // Delegation section
    public entry fun request_add_delegation(
        self: &mut SuiSystemState,
        delegate_stake: Coin<SUI>,
        validator_address: address,
        ctx: &mut TxContext,
    ) {
        sui_system::request_add_delegation(self, delegate_stake, validator_address, ctx);
    }

    public entry fun request_remove_delegation(
        self: &mut SuiSystemState,
        delegation: &mut Delegation,
        ctx: &mut TxContext,
    ) {
        sui_system::request_remove_delegation(self, delegation, ctx);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(SUIX {}, ctx)
    }
}

#[test_only]
module suix::suix_tests {
    use sui::coin::{mint_for_testing as mint, destroy_for_testing as burn};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use suix::suix::{Self, Pool, SUIX };
    use sui::sui::SUI;

    // Tests section
   #[test] fun test_init_pool() { test_init_pool_(&mut scenario()) }
   #[test] fun test_add_liquidity() { test_add_liquidity_(&mut scenario()) }
   #[test] fun test_remove_liquidity() { test_remove_liquidity_(&mut scenario()) }


    fun test_init_pool_(test: &mut Scenario) {
        let (owner, _) = people();

        next_tx(test, &owner); {
            suix::init_for_testing(ctx(test));
        };


        next_tx(test, &owner); {
            let pool = test::take_shared<Pool>(test);
            let pool_mut = test::borrow_mut(&mut pool);
            let (amt_sui, suix_supply) = suix::get_amounts(pool_mut);

            assert!(suix_supply == 0, suix_supply);
            assert!(amt_sui == 0, 0);

            test::return_shared(test, pool)
        };
    }

    fun test_add_liquidity_(test: &mut Scenario) {
        test_init_pool_(test);

        let (_, theguy) = people();

        next_tx(test, &theguy); {
            let pool = test::take_shared<Pool>(test);
            let pool_mut = test::borrow_mut(&mut pool);

            let suix_tokens = suix::add_liquidity(
                pool_mut,
                mint<SUI>(100, ctx(test)),
                ctx(test)
            );

            let (_, suix_supply) = suix::get_amounts(pool_mut);
            assert!(burn(suix_tokens) == suix_supply, 1);

            test::return_shared(test, pool)
        };
    }


    /// Expect SUIX tokens to double in supply when the same values passed
    fun test_remove_liquidity_(test: &mut Scenario) {
        test_init_pool_(test);

        let (_, theguy) = people();

        next_tx(test, &theguy); {
            let pool = test::take_shared<Pool>(test);
            let pool_mut = test::borrow_mut(&mut pool);

            let suix_tokens = suix::add_liquidity(
                pool_mut,
                mint<SUI>(100, ctx(test)),
                ctx(test)
            );

            let (_, suix_supply) = suix::get_amounts(pool_mut);
            assert!(burn(suix_tokens) == suix_supply, 1);

            test::return_shared(test, pool)
        };

        next_tx(test, &theguy); {
            let pool = test::take_shared<Pool>(test);
            let pool_mut = test::borrow_mut(&mut pool);

            let sui = suix::remove_liquidity(
                pool_mut,
                mint<SUIX>(100, ctx(test)),
                ctx(test)
            );

            let (_, suix_supply) = suix::get_amounts(pool_mut);
            assert!(0 == suix_supply, suix_supply);

            assert!(burn(sui) == 100, 1);
            test::return_shared(test, pool)
        };
    }

    // utilities
    fun scenario(): Scenario { test::begin(&@0x1) }
    fun people(): (address, address) { (@0xBEEF, @0xA11CE) }
}