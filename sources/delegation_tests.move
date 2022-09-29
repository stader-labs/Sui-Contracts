#[test_only]
module suix::delegation_tests {
    use sui::coin;
    use suix::suix::{Self, OwnerCap};
    use sui::epoch_reward_record::EpochRewardRecord;
    use sui::test_scenario::{Self, Scenario, ctx};
    use sui::sui_system::{Self, SuiSystemState};
    use sui::delegation::{Self, Delegation};
    use sui::governance_test_utils::{
        Self, 
        create_validator_for_testing, 
        create_sui_system_state_for_testing
    };

    const VALIDATOR_ADDR_1: address = @0x1;
    const VALIDATOR_ADDR_2: address = @0x2;

    const DELEGATOR_ADDR_1: address = @0xA11CE;
    const DELEGATOR_ADDR_2: address = @0xB0b;

    #[test]
    fun test_add_remove_delegation_flow() {
        let scenario = &mut test_scenario::begin(&VALIDATOR_ADDR_1);
        set_up_sui_system_state(scenario);

        test_scenario::next_tx(scenario, &DELEGATOR_ADDR_1);
        {
            suix::init_for_testing(ctx(scenario));
            let system_state_wrapper = test_scenario::take_shared<SuiSystemState>(scenario);
            let system_state_mut_ref = test_scenario::borrow_mut(&mut system_state_wrapper);
            let owner_cap = test_scenario::take_owned<OwnerCap>(scenario);

            let ctx = test_scenario::ctx(scenario);

            // Create two delegations to VALIDATOR_ADDR_1.
            suix::request_add_delegation(&owner_cap,
                system_state_mut_ref, coin::mint_for_testing(10, ctx), VALIDATOR_ADDR_1, ctx);
            suix::request_add_delegation(&owner_cap,
                system_state_mut_ref, coin::mint_for_testing(60, ctx), VALIDATOR_ADDR_1, ctx);

            // Advance the epoch so that the delegation changes can take into effect.
            governance_test_utils::advance_epoch(system_state_mut_ref, scenario);

            // Check that the delegation amount and count are changed correctly.
            assert!(sui_system::validator_delegate_amount(system_state_mut_ref, VALIDATOR_ADDR_1) == 70, 1);
            assert!(sui_system::validator_delegate_amount(system_state_mut_ref, VALIDATOR_ADDR_2) == 0, 2);
            assert!(sui_system::validator_delegator_count(system_state_mut_ref, VALIDATOR_ADDR_1) == 2, 3);
            assert!(sui_system::validator_delegator_count(system_state_mut_ref, VALIDATOR_ADDR_2) == 0, 4);
            test_scenario::return_owned(scenario, owner_cap);
            test_scenario::return_shared(scenario, system_state_wrapper);
        };

        
        test_scenario::next_tx(scenario, &DELEGATOR_ADDR_1);
        {
            
            let owner_cap = test_scenario::take_owned<OwnerCap>(scenario);
            let delegation = test_scenario::take_last_created_owned<Delegation>(scenario);
            assert!(delegation::delegate_amount(&delegation) == 60, 105);

            
            let system_state_wrapper = test_scenario::take_shared<SuiSystemState>(scenario);
            let system_state_mut_ref = test_scenario::borrow_mut(&mut system_state_wrapper);

            let ctx = test_scenario::ctx(scenario);

            // Undelegate 60 SUIs from VALIDATOR_ADDR_1
            suix::request_remove_delegation(&owner_cap,
                system_state_mut_ref, &mut delegation, ctx);

            // Check that the delegation object indeed becomes inactive.
            assert!(!delegation::is_active(&delegation), 106);
            test_scenario::return_owned(scenario, delegation);

            governance_test_utils::advance_epoch(system_state_mut_ref, scenario);

            assert!(sui_system::validator_delegate_amount(system_state_mut_ref, VALIDATOR_ADDR_1) == 10, 107);
            assert!(sui_system::validator_delegator_count(system_state_mut_ref, VALIDATOR_ADDR_1) == 1, 108);
            test_scenario::return_owned(scenario, owner_cap);
            test_scenario::return_shared(scenario, system_state_wrapper);
        };
    }
    #[test]
    #[expected_failure(abort_code = 0)]
    fun test_double_claim_reward_active() {

        let scenario = &mut test_scenario::begin(&VALIDATOR_ADDR_1);
        let ctx = test_scenario::ctx(scenario);
        create_sui_system_state_for_testing(
            vector[create_validator_for_testing(VALIDATOR_ADDR_1, 100, ctx)], 300, 100);

        test_scenario::next_tx(scenario, &DELEGATOR_ADDR_1);
        {
            suix::init_for_testing(ctx(scenario));
            let owner_cap = test_scenario::take_owned<OwnerCap>(scenario);
            let system_state_wrapper = test_scenario::take_shared<SuiSystemState>(scenario);
            let system_state_mut_ref = test_scenario::borrow_mut(&mut system_state_wrapper);

            let ctx = test_scenario::ctx(scenario);

            suix::request_add_delegation(&owner_cap,
                system_state_mut_ref, coin::mint_for_testing(10, ctx), VALIDATOR_ADDR_1, ctx);

            // Advance the epoch twice so that the delegation and rewards can take into effect.
            governance_test_utils::advance_epoch(system_state_mut_ref, scenario);
            governance_test_utils::advance_epoch(system_state_mut_ref, scenario);
            test_scenario::return_owned(scenario, owner_cap);
            test_scenario::return_shared(scenario, system_state_wrapper);
        };

        test_scenario::next_tx(scenario, &DELEGATOR_ADDR_1);
        {
            let owner_cap = test_scenario::take_owned<OwnerCap>(scenario);
            let delegation = test_scenario::take_last_created_owned<Delegation>(scenario);
            let system_state_wrapper = test_scenario::take_shared<SuiSystemState>(scenario);
            let system_state_mut_ref = test_scenario::borrow_mut(&mut system_state_wrapper);
            let epoch_reward_record_wrapper = test_scenario::take_last_created_shared<EpochRewardRecord>(scenario);
            let epoch_reward_record_ref = test_scenario::borrow_mut(&mut epoch_reward_record_wrapper);
            let ctx = test_scenario::ctx(scenario);


            suix::claim_delegation_reward(&owner_cap, system_state_mut_ref, &mut delegation, epoch_reward_record_ref, ctx);

            // // We are claiming the same reward twice so this call should fail.
            suix::claim_delegation_reward(&owner_cap, system_state_mut_ref, &mut delegation, epoch_reward_record_ref, ctx);

            test_scenario::return_owned(scenario, owner_cap);
            test_scenario::return_owned(scenario, delegation);
            test_scenario::return_shared(scenario, epoch_reward_record_wrapper);
            test_scenario::return_shared(scenario, system_state_wrapper);
        }

    }

    fun set_up_sui_system_state(scenario: &mut Scenario) {
        let ctx = test_scenario::ctx(scenario);

        let validators = vector[
            create_validator_for_testing(VALIDATOR_ADDR_1, 100, ctx), 
            create_validator_for_testing(VALIDATOR_ADDR_2, 100, ctx)
        ];
        create_sui_system_state_for_testing(validators, 300, 100);
    }
}