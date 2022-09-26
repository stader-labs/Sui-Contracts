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
        lsp_supply: Supply<SUIX>,
        /// Fee Percent is denominated in basis points.
        fee_percent: u64
    }

    fun init(witness: SUIX, ctx: &mut TxContext) {
        transfer::share_object(Pool {
            id: object::new(ctx),
            sui: balance::zero<SUI>(),
            lsp_supply: balance::create_supply(witness),
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

        let balance = balance::increase_supply(&mut pool.lsp_supply, share_minted);

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

        balance::decrease_supply(&mut pool.lsp_supply, coin::into_balance(lsp));

        coin::take(&mut pool.sui, sui_removed, ctx)
    }
}