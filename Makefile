.PHONY: build
.PHONY: publish
.PHONY: test

publish:
	sui client publish --path . --gas-budget 10000

build:
	sui move build
test:
	sui move test --force | aptos-pprint
