module cellana::gauge {
    use std::signer;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::{Self, FungibleAsset};
    use aptos_framework::timestamp;
    use aptos_std::table_with_length::{Self as Table, TableWithLength};
    use std::string::String;

    /// Errors
    const ERROR_NOT_ADMIN: u64 = 1;
    const ERROR_INSUFFICIENT_BALANCE: u64 = 2;
    const ERROR_USER_INFO_NOT_EXIST: u64 = 3;

    /// Stores gauge info for a liquidity pool
    struct Gauge has key {
        /// Total staked LP tokens
        total_staked: u128,
        /// Accumulated rewards per share, scaled by ACC_PRECISION 
        acc_reward_per_share: u128,
        /// Last reward timestamp
        last_reward_timestamp: u64,
        /// Allocation points for reward distribution
        alloc_point: u64,
        /// User info mapping
        user_info: TableWithLength<address, UserInfo>,
    }

    /// User staking info
    struct UserInfo has store {
        /// Amount of LP tokens staked
        amount: u128,
        /// Reward debt for calculating pending rewards
        reward_debt: u128
    }

    /// Constants
    const ACC_PRECISION: u128 = 1000000000000;

    /// Create a new gauge for a liquidity pool
    public fun create_gauge(creator: &signer, alloc_point: u64): Object<Gauge> {
        let constructor_ref = object::create_object_from_account(creator);
        let gauge = Gauge {
            total_staked: 0,
            acc_reward_per_share: 0,
            last_reward_timestamp: timestamp::now_seconds(),
            alloc_point,
            user_info: Table::new()
        };
        move_to(&object::generate_signer(&constructor_ref), gauge);
        object::object_from_constructor_ref(&constructor_ref)
    }

    /// Stake LP tokens into gauge
    public fun stake(user: &signer, gauge_obj: Object<Gauge>, lp_tokens: FungibleAsset) acquires Gauge {
        let user_addr = signer::address_of(user);
        let gauge = borrow_global_mut<Gauge>(object::object_address(&gauge_obj));
        
        // Update gauge state
        update_gauge(gauge);

        // Get or create user info
        if (!Table::contains(&gauge.user_info, user_addr)) {
            Table::add(&mut gauge.user_info, user_addr, UserInfo {
                amount: 0,
                reward_debt: 0
            });
        };

        let user_info = Table::borrow_mut(&mut gauge.user_info, user_addr);
        let amount = (fungible_asset::amount(&lp_tokens) as u128);

        // Update user state
        if (user_info.amount > 0) {
            // Harvest pending rewards before adding more stake
            let pending = (user_info.amount * gauge.acc_reward_per_share) / ACC_PRECISION - user_info.reward_debt;
            if (pending > 0) {
                // Transfer rewards to user
                // Note: Actual reward transfer implementation needed
            };
        };

        user_info.amount = user_info.amount + amount;
        user_info.reward_debt = user_info.amount * gauge.acc_reward_per_share / ACC_PRECISION;
        gauge.total_staked = gauge.total_staked + amount;

        // Transfer LP tokens to gauge
        fungible_asset::deposit(object::object_address(&gauge_obj), lp_tokens);
    }

    /// Unstake LP tokens from gauge
    public fun unstake_lp(user: &signer, gauge_obj: Object<Gauge>, amount: u64) acquires Gauge {
        let user_addr = signer::address_of(user);
        let gauge = borrow_global_mut<Gauge>(object::object_address(&gauge_obj));
        
        let user_info = Table::borrow_mut(&mut gauge.user_info, user_addr);
        assert!((amount as u128) <= user_info.amount, ERROR_INSUFFICIENT_BALANCE);

        // Update gauge state
        update_gauge(gauge);

        // Calculate pending rewards
        let pending = (user_info.amount * gauge.acc_reward_per_share) / ACC_PRECISION - user_info.reward_debt;
        if (pending > 0) {
            // Transfer rewards to user
            // Note: Actual reward transfer implementation needed
        };

        // Update user state
        user_info.amount = user_info.amount - (amount as u128);
        user_info.reward_debt = user_info.amount * gauge.acc_reward_per_share / ACC_PRECISION;
        gauge.total_staked = gauge.total_staked - (amount as u128);

        // Return LP tokens to user
        let lp_tokens = fungible_asset::withdraw(
            &object::generate_signer(&object::create_object_from_account(user)), 
            amount
        );
        fungible_asset::deposit(user_addr, lp_tokens);
    }

    /// Update gauge reward state
    fun update_gauge(gauge: &mut Gauge) {
        let current_time = timestamp::now_seconds();
        if (current_time <= gauge.last_reward_timestamp) {
            return
        };

        if (gauge.total_staked == 0) {
            gauge.last_reward_timestamp = current_time;
            return
        };

        let time_elapsed = current_time - gauge.last_reward_timestamp;
        
        // Calculate rewards
        // Note: Actual reward calculation implementation needed based on alloc_point
        let reward = time_elapsed * (gauge.alloc_point as u128);
        
        gauge.acc_reward_per_share = gauge.acc_reward_per_share + 
            (reward * ACC_PRECISION) / gauge.total_staked;
        gauge.last_reward_timestamp = current_time;
    }

    #[view]
    public fun get_gauge_info(gauge_obj: Object<Gauge>): (u128, u128, u64, u64) acquires Gauge {
        let gauge = borrow_global<Gauge>(object::object_address(&gauge_obj));
        (
            gauge.total_staked,
            gauge.acc_reward_per_share,
            gauge.last_reward_timestamp,
            gauge.alloc_point
        )
    }

    #[view] 
    public fun get_user_info(gauge_obj: Object<Gauge>, user: address): (u128, u128) acquires Gauge {
        let gauge = borrow_global<Gauge>(object::object_address(&gauge_obj));
        assert!(Table::contains(&gauge.user_info, user), ERROR_USER_INFO_NOT_EXIST);
        let user_info = Table::borrow(&gauge.user_info, user);
        (user_info.amount, user_info.reward_debt)
    }
} 