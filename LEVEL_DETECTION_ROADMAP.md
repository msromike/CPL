# CPL Level Detection Strategy Roadmap

## Tier 1: Free/Instant Sources (No Limits)

- **Current Target**: UnitLevel("target") - Hook PLAYER_TARGET_CHANGED
- **Party/Raid**: UnitLevel("party1-4", "raid1-40") - Hook GROUP_ROSTER_UPDATE
- **Guild Members**: GetGuildRosterInfo() - Hook GUILD_ROSTER_UPDATE (refresh every 30min)
- **Friends List**: C_FriendList.GetFriendInfo() - Hook BN_FRIEND_INFO_CHANGED

## Tier 2: Limited Query Sources (Rate Limited)

- **/who Queries**: 1 per 6-10 seconds, queue unknown chatting players, FIFO processing
- **Inspection**: NotifyInspect() on mouseover, higher rate than /who but proximity limited

## Tier 3: Fallback Strategies

- **Social Inference**: Cross-reference guild member mentions with known levels
- **Historical Patterns**: Track level progression over time, estimate growth

## Smart Limits Framework

- **Time-based**: 6s between /who, 30min guild refresh
- **Frequency-based**: Max 10 /who per minute, then exponential backoff
- **Priority-based**: Guild > chatting players > random mentions
- **Staleness-based**: Refresh data older than 7 days first

## Implementation Order

1. Test Tier 1 (targeting + guild roster) - zero rate limit risk
2. Add Tier 2 with conservative limits
3. Implement Tier 3 optimizations
4. Fine-tune limits based on actual usage patterns
