# SUIX

# build:

`make build`

# publish:

`make publish`

Devnet: ${SUIX}

# add liquidity:

```
    sui client call --gas-budget 1000 --package $SUIX --module "suix" --function "add_liquidity_" --args "0xa4f65e3ec9ffabab2615011d5017f43c635f2404" $YOUR_SUI
```

# remove liquidity:

```
sui client call --gas-budget 1000 --package ${SUIX} --module "suix" --function "remove_liquidity_" --args "0xa4f65e3ec9ffabab2615011d5017f43c635f2404" $YOUR_SUIX
```
