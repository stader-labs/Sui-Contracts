# SUIX

Devnet: 0xb70d1958b18fc111b67671ac57e8dc81e1670426

# add liquidity:

```
    sui client call --gas-budget 1000 --package 0xb70d1958b18fc111b67671ac57e8dc81e1670426 --module "suix" --function "add_liquidity_" --args 0xfae71973d15aacf98f487ad2ef3d961b0136ed45 $YOUR_SUI
```

# remove liquidity:

```
sui client call --gas-budget 1000 --package 0xb70d1958b18fc111b67671ac57e8dc81e1670426 --module "suix" --function "remove_liquidity_" --args 0xfae71973d15aacf98f487ad2ef3d961b0136ed45 $YOUR_SUIX
```
