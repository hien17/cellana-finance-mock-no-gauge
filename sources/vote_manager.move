module cellana::vote_manager {
    use std::signer;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::fungible_asset::Metadata;
    use cellana::gauge;
    use cellana::liquidity_pool::LiquidityPool;
    use std::table_with_length::{Self as Table, TableWithLength};

    /// Errors
    const ERROR_NOT_ADMIN: u64 = 1;
    const ERROR_POOL_NOT_WHITELISTED: u64 = 2;

    /// Stores vote manager state
    struct VoteManager has key {
        /// Admin address
        admin: address,
        /// Whitelisted pools
        whitelisted_pools: TableWithLength<Object<LiquidityPool>, bool>,
        /// Pool to gauge mapping
        pool_to_gauge: TableWithLength<Object<LiquidityPool>, Object<gauge::Gauge>>,
    }

    /// Initialize vote manager
    fun init_module(sender: &signer) {
        move_to(sender, VoteManager {
            admin: signer::address_of(sender),
            whitelisted_pools: Table::new(),
            pool_to_gauge: Table::new(),
        });
    }

    /// Whitelist a pool for default rewards
    public fun whitelist_default_reward_pool(pool: Object<LiquidityPool>) acquires VoteManager {
        let vote_manager = borrow_global_mut<VoteManager>(@cellana);
        if (!Table::contains(&vote_manager.whitelisted_pools, pool)) {
            Table::add(&mut vote_manager.whitelisted_pools, pool, true);
        };
    }

    /// Create gauge for a pool
    public(friend) fun create_gauge_internal(pool: Object<LiquidityPool>) acquires VoteManager {
        let vote_manager = borrow_global_mut<VoteManager>(@cellana);
        assert!(Table::contains(&vote_manager.whitelisted_pools, pool), ERROR_POOL_NOT_WHITELISTED);

        if (!Table::contains(&vote_manager.pool_to_gauge, pool)) {
            let gauge_obj = gauge::create_gauge(&object::create_signer_from_address(@cellana), 1);
            Table::add(&mut vote_manager.pool_to_gauge, pool, gauge_obj);
        };
    }

    /// Get gauge for a pool
    public fun get_gauge(pool: Object<LiquidityPool>): Object<gauge::Gauge> acquires VoteManager {
        let vote_manager = borrow_global<VoteManager>(@cellana);
        *Table::borrow(&vote_manager.pool_to_gauge, pool)
    }

    /// Check if pool is whitelisted
    public fun is_whitelisted(pool: Object<LiquidityPool>): bool acquires VoteManager {
        let vote_manager = borrow_global<VoteManager>(@cellana);
        Table::contains(&vote_manager.whitelisted_pools, pool)
    }
} 