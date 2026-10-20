/** Keep the installed OdysseyContractV1 root envelope closed.
 * Delivery is additive state presentation metadata, never a currency authority.
 * Normalize at the HTTP boundary, including historical persisted action replays.
 * Do not mutate stored state, commands, receipts or response journals.
 */
export function odysseyWire(data,env={}) {
 if(!data || typeof data!=='object' || !data.state || typeof data.state!=='object')return data;
 const {ad_delivery:delivery,board_rewards:board,...root}=data;
 if(!delivery&&!board)return root;
 return {...root,state:{...data.state,
  ...(board?{board_rewards:structuredClone(board)}:{}),
  ...(delivery?{ad_delivery:{...delivery,
   expected_unit:env.ODYSSEY_AD_UNIT||'',
   expected_reward_item:env.ODYSSEY_AD_REWARD_ITEM||''}}:{})}};
}
