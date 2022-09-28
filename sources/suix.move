module suix::suix {
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Supply, Balance};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct SUIX has drop {}

    /// For when supplied Coin is zero.
    const EZeroAmount: u64 = 0;

    struct Pool has key {
        id: UID,
        sui: Balance<SUI>,
        suix_supply: Supply<SUIX>,
        /// Fee Percent is denominated in basis points.
        fee_percent: u64
    }

    fun init(witness: SUIX, ctx: &mut TxContext) {
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
    entry fun remove_liquidity_<P, T>(
        pool: &mut Pool,
        lsp: Coin<SUIX>,
        ctx: &mut TxContext
    ) {
        let (sui ) = remove_liquidity(pool, lsp, ctx);
        let sender = tx_context::sender(ctx);

        transfer::transfer(sui, sender);
    }

    /// Remove liquidity from the `Pool` by burning `SUIX`.
    /// Returns `Coin<SUI>`.
    public fun remove_liquidity (
        pool: &mut Pool,
        lsp: Coin<SUIX>,
        ctx: &mut TxContext
    ): Coin<SUI> {
        let lsp_amount = coin::value(&lsp);

        // If there's a non-empty LSP, we can
        assert!(lsp_amount > 0, EZeroAmount);

        let sui_removed = lsp_amount;

        balance::decrease_supply(&mut pool.suix_supply, coin::into_balance(lsp));

        coin::take(&mut pool.sui, sui_removed, ctx)
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
        // utilities
    // use sui::coin::{mint_for_testing as mint, destroy_for_testing as burn};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    use suix::suix::{Self, Pool };

    // Tests section
   #[test] fun test_init_pool() { test_init_pool_(&mut scenario()) }

    fun scenario(): Scenario { test::begin(&@0x1) }

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

     fun people(): (address, address) { (@0xBEEF, @0xA11CE) }
}