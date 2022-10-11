# SUIX

# build:

`make build`

# publish:

`make publish`

Devnet: ${SUIX}

# add liquidity:

```
    sui client call --gas-budget 1000 --package $SUIX --module "suix" --function "add_liquidity_" --args $SUIX_POOL $YOUR_SUI
```

# remove liquidity:

```
sui client call --gas-budget 1000 --package ${SUIX} --module "suix" --function "remove_liquidity_" --args $SUIX_POOL $YOUR_SUIX
```
