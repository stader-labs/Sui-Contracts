module suix::suix {
    use sui::coin;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct SUIX has drop {}

    fun init(witness: SUIX, ctx: &mut TxContext) {
        transfer::transfer(
            coin::create_currency(witness, ctx),
            tx_context::sender(ctx)
        )
    }
}
