---
title: "DB Table Catalog"
category: database
agent_hint: "Load to find which domain a table belongs to and its foreign key and procedure counts."
index_tier: lazy
type: database
status: live
environment: dev
side: shared
owner: syed
source: "script file dev-06-10-2026-Schema-Only.sql"
snapshot_as_of: 2026-10-14T16:39:38
last_verified: 2026-10-14
generated: true
tags: [database, side/shared]
---

# DB Table Catalog

All tables. Part of [[DB Current State]].

| Table | Domain | Columns | FK out | FK in | Procs touching |
|---|---|---|---|---|---|
| [[DB Content Media and Approval#activity_log|activity_log]] | Content Media and Approval | 9 | 0 | 0 | 2 |
| [[DB Ads Campaigns and Charity#ad_3d_model|ad_3d_model]] | Ads Campaigns and Charity | 12 | 2 | 1 | 12 |
| [[DB Ads Campaigns and Charity#ad_placement|ad_placement]] | Ads Campaigns and Charity | 8 | 1 | 1 | 19 |
| [[DB Ads Campaigns and Charity#ad_placement_migration_log|ad_placement_migration_log]] | Ads Campaigns and Charity | 14 | 0 | 0 | 0 |
| [[DB Ads Campaigns and Charity#ad_schedule_dates|ad_schedule_dates]] | Ads Campaigns and Charity | 8 | 2 | 0 | 16 |
| [[DB Ads Campaigns and Charity#advertiser|advertiser]] | Ads Campaigns and Charity | 11 | 1 | 1 | 32 |
| [[DB Ads Campaigns and Charity#advertiser_ad|advertiser_ad]] | Ads Campaigns and Charity | 13 | 4 | 3 | 21 |
| [[DB Ads Campaigns and Charity#advertiser_campaign|advertiser_campaign]] | Ads Campaigns and Charity | 16 | 1 | 1 | 26 |
| [[DB Content Media and Approval#audit_log|audit_log]] | Content Media and Approval | 9 | 0 | 0 | 0 |
| [[DB Users and Auth#avatar|avatar]] | Users and Auth | 6 | 2 | 0 | 12 |
| [[DB Users and Auth#badge|badge]] | Users and Auth | 7 | 2 | 2 | 15 |
| [[DB Content Media and Approval#blob_upload|blob_upload]] | Content Media and Approval | 8 | 0 | 0 | 4 |
| [[DB Booths Portals and Teleport#booth|booth]] | Booths Portals and Teleport | 11 | 2 | 5 | 15 |
| [[DB Booths Portals and Teleport#booth_comment|booth_comment]] | Booths Portals and Teleport | 11 | 4 | 0 | 1 |
| [[DB Booths Portals and Teleport#booth_media|booth_media]] | Booths Portals and Teleport | 9 | 2 | 0 | 10 |
| [[DB Ads Campaigns and Charity#campaign_status|campaign_status]] | Ads Campaigns and Charity | 5 | 0 | 1 | 0 |
| [[DB Ads Campaigns and Charity#charity|charity]] | Ads Campaigns and Charity | 14 | 0 | 2 | 8 |
| [[DB Ads Campaigns and Charity#charity_campaigns|charity_campaigns]] | Ads Campaigns and Charity | 14 | 5 | 0 | 0 |
| [[DB Content Media and Approval#content_approval|content_approval]] | Content Media and Approval | 20 | 4 | 0 | 43 |
| [[DB Content Media and Approval#content_version|content_version]] | Content Media and Approval | 4 | 0 | 0 | 2 |
| [[DB Shop Items and Orders#currency|currency]] | Shop Items and Orders | 9 | 0 | 15 | 13 |
| [[DB Booths Portals and Teleport#custom_booth_item|custom_booth_item]] | Booths Portals and Teleport | 14 | 3 | 1 | 8 |
| [[DB Booths Portals and Teleport#custom_booth_item_link|custom_booth_item_link]] | Booths Portals and Teleport | 11 | 2 | 0 | 5 |
| [[DB Booths Portals and Teleport#custom_booth_item_type|custom_booth_item_type]] | Booths Portals and Teleport | 9 | 0 | 1 | 4 |
| [[DB Shop Items and Orders#discount_type|discount_type]] | Shop Items and Orders | 5 | 0 | 1 | 1 |
| [[DB Shop Items and Orders#discounts|discounts]] | Shop Items and Orders | 15 | 1 | 1 | 19 |
| [[DB Payments#dispute_status|dispute_status]] | Payments | 5 | 0 | 1 | 0 |
| [[DB Shop Items and Orders#entitlement|entitlement]] | Shop Items and Orders | 11 | 3 | 0 | 5 |
| [[DB Shop Items and Orders#entitlement_status|entitlement_status]] | Shop Items and Orders | 5 | 0 | 1 | 1 |
| [[DB Spaces and Access#entity|entity]] | Spaces and Access | 14 | 4 | 11 | 21 |
| [[DB Spaces and Access#entity_type|entity_type]] | Spaces and Access | 5 | 0 | 0 | 1 |
| [[DB Events#event|event]] | Events | 24 | 5 | 8 | 15 |
| [[DB Events#event_format|event_format]] | Events | 8 | 0 | 1 | 4 |
| [[DB Events#event_reviews|event_reviews]] | Events | 9 | 2 | 0 | 0 |
| [[DB Metrics and Activity#event_shares_mtx|event_shares_mtx]] | Metrics and Activity | 8 | 2 | 0 | 1 |
| [[DB Events#event_type|event_type]] | Events | 6 | 0 | 1 | 4 |
| [[DB Games and Leaderboards#fastest_runner_game|fastest_runner_game]] | Games and Leaderboards | 10 | 2 | 0 | 0 |
| [[DB Shop Items and Orders#free_trial_items|free_trial_items]] | Shop Items and Orders | 10 | 3 | 0 | 15 |
| [[DB Shop Items and Orders#free_trial_settings|free_trial_settings]] | Shop Items and Orders | 11 | 1 | 0 | 13 |
| [[DB Friends#friend|friend]] | Friends | 8 | 3 | 0 | 5 |
| [[DB Friends#friend_notification|friend_notification]] | Friends | 11 | 4 | 0 | 5 |
| [[DB Friends#friend_notification_type|friend_notification_type]] | Friends | 5 | 0 | 1 | 3 |
| [[DB Friends#friend_request|friend_request]] | Friends | 10 | 4 | 0 | 8 |
| [[DB Friends#friend_request_status|friend_request_status]] | Friends | 5 | 0 | 1 | 8 |
| [[DB Games and Leaderboards#game|game]] | Games and Leaderboards | 10 | 0 | 9 | 8 |
| [[DB Games and Leaderboards#game_announcement|game_announcement]] | Games and Leaderboards | 15 | 2 | 3 | 7 |
| [[DB Games and Leaderboards#game_announcement_prize_pack|game_announcement_prize_pack]] | Games and Leaderboards | 6 | 2 | 0 | 4 |
| [[DB Games and Leaderboards#game_announcement_user_prize|game_announcement_user_prize]] | Games and Leaderboards | 8 | 3 | 0 | 1 |
| [[DB Games and Leaderboards#game_announcement_winner|game_announcement_winner]] | Games and Leaderboards | 10 | 3 | 0 | 3 |
| [[DB Games and Leaderboards#game_badges|game_badges]] | Games and Leaderboards | 6 | 2 | 0 | 0 |
| [[DB Games and Leaderboards#game_difficulty|game_difficulty]] | Games and Leaderboards | 6 | 0 | 2 | 0 |
| [[DB Games and Leaderboards#game_option|game_option]] | Games and Leaderboards | 7 | 2 | 1 | 0 |
| [[DB Payments#gateway_event_log|gateway_event_log]] | Payments | 11 | 4 | 0 | 0 |
| [[DB Spaces and Access#geolocation|geolocation]] | Spaces and Access | 7 | 1 | 1 | 0 |
| [[DB Spaces and Access#global_ccu_settings|global_ccu_settings]] | Spaces and Access | 8 | 0 | 0 | 2 |
| [[DB Games and Leaderboards#guess_player_game|guess_player_game]] | Games and Leaderboards | 8 | 4 | 1 | 0 |
| [[DB Games and Leaderboards#guess_player_game_clue|guess_player_game_clue]] | Games and Leaderboards | 6 | 1 | 1 | 0 |
| [[DB Booths Portals and Teleport#hosting|hosting]] | Booths Portals and Teleport | 12 | 2 | 0 | 13 |
| [[DB Content Media and Approval#i18n|i18n]] | Content Media and Approval | 10 | 2 | 0 | 105 |
| [[DB Content Media and Approval#i18n_locale|i18n_locale]] | Content Media and Approval | 5 | 0 | 4 | 5 |
| [[DB Content Media and Approval#image_data|image_data]] | Content Media and Approval | 2 | 0 | 0 | 0 |
| [[DB Payments#invoice|invoice]] | Payments | 27 | 7 | 1 | 3 |
| [[DB Payments#invoice_line_item|invoice_line_item]] | Payments | 15 | 3 | 0 | 1 |
| [[DB Payments#invoice_status|invoice_status]] | Payments | 5 | 0 | 1 | 0 |
| [[DB Shop Items and Orders#item|item]] | Shop Items and Orders | 16 | 3 | 13 | 33 |
| [[DB Shop Items and Orders#item_discounts|item_discounts]] | Shop Items and Orders | 9 | 3 | 0 | 16 |
| [[DB Shop Items and Orders#item_prices|item_prices]] | Shop Items and Orders | 7 | 2 | 0 | 15 |
| [[DB Shop Items and Orders#item_type|item_type]] | Shop Items and Orders | 5 | 0 | 3 | 4 |
| [[DB Spaces and Access#light_config|light_config]] | Spaces and Access | 8 | 1 | 1 | 0 |
| [[DB Users and Auth#login_type|login_type]] | Users and Auth | 5 | 0 | 1 | 16 |
| [[DB Booths Portals and Teleport#map_spot|map_spot]] | Booths Portals and Teleport | 7 | 0 | 2 | 12 |
| [[DB Content Media and Approval#media|media]] | Content Media and Approval | 10 | 2 | 17 | 58 |
| [[DB Content Media and Approval#media_localization|media_localization]] | Content Media and Approval | 9 | 2 | 0 | 73 |
| [[DB Content Media and Approval#media_type|media_type]] | Content Media and Approval | 5 | 0 | 1 | 7 |
| [[DB Shop Items and Orders#merchandise|merchandise]] | Shop Items and Orders | 8 | 4 | 0 | 15 |
| [[DB Shop Items and Orders#merchandise_category|merchandise_category]] | Shop Items and Orders | 5 | 0 | 1 | 10 |
| [[DB Shop Items and Orders#merchandise_type|merchandise_type]] | Shop Items and Orders | 7 | 0 | 1 | 10 |
| [[DB Metrics and Activity#metric_idempotency_key|metric_idempotency_key]] | Metrics and Activity | 5 | 0 | 0 | 0 |
| [[DB Games and Leaderboards#option_text|option_text]] | Games and Leaderboards | 5 | 0 | 1 | 0 |
| [[DB Shop Items and Orders#order_adjustment|order_adjustment]] | Shop Items and Orders | 14 | 3 | 0 | 3 |
| [[DB Shop Items and Orders#order_adjustment_type|order_adjustment_type]] | Shop Items and Orders | 5 | 0 | 1 | 0 |
| [[DB Shop Items and Orders#order_line_item|order_line_item]] | Shop Items and Orders | 14 | 3 | 2 | 12 |
| [[DB Shop Items and Orders#order_status|order_status]] | Shop Items and Orders | 5 | 0 | 1 | 0 |
| [[DB Shop Items and Orders#orders|orders]] | Shop Items and Orders | 23 | 6 | 6 | 23 |
| [[DB Shop Items and Orders#package|package]] | Shop Items and Orders | 14 | 2 | 3 | 10 |
| [[DB Shop Items and Orders#package_item|package_item]] | Shop Items and Orders | 8 | 2 | 0 | 10 |
| [[DB Payments#payment_audit_log|payment_audit_log]] | Payments | 11 | 0 | 0 | 1 |
| [[DB Payments#payment_charge|payment_charge]] | Payments | 22 | 4 | 4 | 13 |
| [[DB Payments#payment_deposit|payment_deposit]] | Payments | 13 | 1 | 0 | 7 |
| [[DB Payments#payment_destination|payment_destination]] | Payments | 9 | 2 | 0 | 0 |
| [[DB Payments#payment_dispute|payment_dispute]] | Payments | 12 | 3 | 0 | 0 |
| [[DB Payments#payment_gateway|payment_gateway]] | Payments | 5 | 0 | 8 | 6 |
| [[DB Payments#payment_gateway_config|payment_gateway_config]] | Payments | 13 | 3 | 1 | 5 |
| [[DB Payments#payment_gateway_config_currency|payment_gateway_config_currency]] | Payments | 7 | 2 | 0 | 0 |
| [[DB Payments#payment_intent|payment_intent]] | Payments | 14 | 5 | 2 | 20 |
| [[DB Payments#payment_method_type|payment_method_type]] | Payments | 5 | 0 | 2 | 0 |
| [[DB Payments#payment_refund|payment_refund]] | Payments | 15 | 3 | 1 | 6 |
| [[DB Payments#payment_status|payment_status]] | Payments | 5 | 0 | 2 | 0 |
| [[DB Spaces and Access#pending_invitation|pending_invitation]] | Spaces and Access | 15 | 3 | 0 | 21 |
| [[DB Users and Auth#personality|personality]] | Users and Auth | 12 | 3 | 2 | 6 |
| [[DB Spaces and Access#platform_type|platform_type]] | Spaces and Access | 5 | 0 | 6 | 5 |
| [[DB Booths Portals and Teleport#portal|portal]] | Booths Portals and Teleport | 14 | 6 | 2 | 22 |
| [[DB Metrics and Activity#portal_access_mtx|portal_access_mtx]] | Metrics and Activity | 14 | 6 | 0 | 2 |
| [[DB Booths Portals and Teleport#portal_link|portal_link]] | Booths Portals and Teleport | 11 | 3 | 0 | 13 |
| [[DB Booths Portals and Teleport#portal_position|portal_position]] | Booths Portals and Teleport | 5 | 0 | 1 | 0 |
| [[DB Booths Portals and Teleport#portal_type|portal_type]] | Booths Portals and Teleport | 6 | 0 | 2 | 0 |
| [[DB Booths Portals and Teleport#predefined_comments|predefined_comments]] | Booths Portals and Teleport | 7 | 0 | 1 | 4 |
| [[DB Games and Leaderboards#predict_match_game|predict_match_game]] | Games and Leaderboards | 9 | 3 | 1 | 0 |
| [[DB Rules Engine#re_comparator|re_comparator]] | Rules Engine | 10 | 0 | 1 | 0 |
| [[DB Rules Engine#re_context_parameter|re_context_parameter]] | Rules Engine | 14 | 2 | 2 | 0 |
| [[DB Rules Engine#re_dropdown_value_provider|re_dropdown_value_provider]] | Rules Engine | 6 | 1 | 1 | 0 |
| [[DB Rules Engine#re_event_type|re_event_type]] | Rules Engine | 5 | 0 | 2 | 0 |
| [[DB Rules Engine#re_event_type_parameter|re_event_type_parameter]] | Rules Engine | 8 | 2 | 0 | 0 |
| [[DB Rules Engine#re_events|re_events]] | Rules Engine | 13 | 5 | 0 | 0 |
| [[DB Rules Engine#re_logical_operator|re_logical_operator]] | Rules Engine | 7 | 0 | 1 | 0 |
| [[DB Rules Engine#re_moderation_action_type|re_moderation_action_type]] | Rules Engine | 5 | 0 | 1 | 0 |
| [[DB Rules Engine#re_moderation_target_selector|re_moderation_target_selector]] | Rules Engine | 5 | 0 | 1 | 0 |
| [[DB Rules Engine#re_moderation_target_type|re_moderation_target_type]] | Rules Engine | 5 | 0 | 1 | 0 |
| [[DB Rules Engine#re_path_type|re_path_type]] | Rules Engine | 5 | 0 | 1 | 0 |
| [[DB Rules Engine#re_provider_type|re_provider_type]] | Rules Engine | 5 | 0 | 1 | 0 |
| [[DB Payments#refund_status|refund_status]] | Payments | 5 | 0 | 1 | 0 |
| [[DB Spaces and Access#region|region]] | Spaces and Access | 8 | 0 | 3 | 1 |
| [[DB Shop Items and Orders#regional_currency|regional_currency]] | Shop Items and Orders | 6 | 1 | 0 | 1 |
| [[DB Rewards#reward|reward]] | Rewards | 19 | 3 | 4 | 0 |
| [[DB Rewards#reward_composition_type|reward_composition_type]] | Rewards | 5 | 0 | 1 | 0 |
| [[DB Rewards#reward_currency|reward_currency]] | Rewards | 7 | 1 | 0 | 0 |
| [[DB Rewards#reward_item|reward_item]] | Rewards | 7 | 2 | 0 | 0 |
| [[DB Rewards#reward_status|reward_status]] | Rewards | 5 | 0 | 1 | 0 |
| [[DB Spaces and Access#role|role]] | Spaces and Access | 7 | 0 | 3 | 30 |
| [[DB Rules Engine#rule_action_moderation|rule_action_moderation]] | Rules Engine | 14 | 4 | 0 | 0 |
| [[DB Rules Engine#rule_action_reward|rule_action_reward]] | Rules Engine | 5 | 2 | 0 | 0 |
| [[DB Rules Engine#rule_action_type|rule_action_type]] | Rules Engine | 6 | 0 | 1 | 0 |
| [[DB Rules Engine#rule_actions|rule_actions]] | Rules Engine | 12 | 2 | 2 | 0 |
| [[DB Rules Engine#rule_condition|rule_condition]] | Rules Engine | 11 | 3 | 0 | 0 |
| [[DB Rules Engine#rule_condition_group|rule_condition_group]] | Rules Engine | 10 | 3 | 2 | 0 |
| [[DB Rules Engine#rule_parameters|rule_parameters]] | Rules Engine | 7 | 1 | 0 | 0 |
| [[DB Rules Engine#rules|rules]] | Rules Engine | 17 | 3 | 4 | 0 |
| [[DB Booths Portals and Teleport#selfie_jumbotron|selfie_jumbotron]] | Booths Portals and Teleport | 8 | 2 | 0 | 0 |
| [[DB Users and Auth#session_status|session_status]] | Users and Auth | 5 | 0 | 1 | 1 |
| [[DB Shop Items and Orders#shop|shop]] | Shop Items and Orders | 9 | 3 | 2 | 9 |
| [[DB Shop Items and Orders#shop_items|shop_items]] | Shop Items and Orders | 9 | 3 | 0 | 20 |
| [[DB Spaces and Access#space|space]] | Spaces and Access | 19 | 2 | 41 | 45 |
| [[DB Spaces and Access#space_config|space_config]] | Spaces and Access | 18 | 1 | 0 | 3 |
| [[DB Spaces and Access#space_lighting|space_lighting]] | Spaces and Access | 7 | 2 | 0 | 0 |
| [[DB Spaces and Access#space_member|space_member]] | Spaces and Access | 13 | 2 | 1 | 23 |
| [[DB Spaces and Access#space_member_role|space_member_role]] | Spaces and Access | 5 | 2 | 0 | 10 |
| [[DB Spaces and Access#sport|sport]] | Spaces and Access | 6 | 0 | 1 | 0 |
| [[DB Spaces and Access#state_type|state_type]] | Spaces and Access | 5 | 0 | 2 | 0 |
| [[DB Content Media and Approval#supported_languages|supported_languages]] | Content Media and Approval | 10 | 2 | 0 | 31 |
| [[DB Payments#supported_payment_gateway|supported_payment_gateway]] | Payments | 6 | 2 | 0 | 0 |
| [[DB Spaces and Access#system_config|system_config]] | Spaces and Access | 5 | 0 | 0 | 0 |
| [[DB Shop Items and Orders#tax_category|tax_category]] | Shop Items and Orders | 7 | 0 | 1 | 16 |
| [[DB Booths Portals and Teleport#teleport_button_position|teleport_button_position]] | Booths Portals and Teleport | 5 | 0 | 0 | 5 |
| [[DB Booths Portals and Teleport#teleport_table|teleport_table]] | Booths Portals and Teleport | 10 | 1 | 2 | 9 |
| [[DB Metrics and Activity#teleport_table_activity_mtx|teleport_table_activity_mtx]] | Metrics and Activity | 7 | 3 | 0 | 1 |
| [[DB Booths Portals and Teleport#teleport_table_button|teleport_table_button]] | Booths Portals and Teleport | 13 | 2 | 1 | 8 |
| [[DB Shop Items and Orders#ticket|ticket]] | Shop Items and Orders | 12 | 3 | 0 | 16 |
| [[DB Shop Items and Orders#ticket_type|ticket_type]] | Shop Items and Orders | 5 | 0 | 1 | 7 |
| [[DB 3D Streaming and Moderation#tifoxr_3d_ai_class_labels|tifoxr_3d_ai_class_labels]] | 3D Streaming and Moderation | 6 | 1 | 0 | 0 |
| [[DB 3D Streaming and Moderation#tifoxr_3d_moderated_class|tifoxr_3d_moderated_class]] | 3D Streaming and Moderation | 5 | 0 | 2 | 0 |
| [[DB 3D Streaming and Moderation#tifoxr_3d_moderation_status|tifoxr_3d_moderation_status]] | 3D Streaming and Moderation | 5 | 0 | 1 | 0 |
| [[DB 3D Streaming and Moderation#tifoxr_3d_question_inbox|tifoxr_3d_question_inbox]] | 3D Streaming and Moderation | 6 | 2 | 0 | 0 |
| [[DB 3D Streaming and Moderation#tifoxr_3d_stream|tifoxr_3d_stream]] | 3D Streaming and Moderation | 7 | 2 | 7 | 0 |
| [[DB 3D Streaming and Moderation#tifoxr_3d_streaming_config|tifoxr_3d_streaming_config]] | 3D Streaming and Moderation | 7 | 1 | 0 | 0 |
| [[DB 3D Streaming and Moderation#tifoxr_3d_streaming_session_summary_mtx|tifoxr_3d_streaming_session_summary_mtx]] | 3D Streaming and Moderation | 9 | 1 | 0 | 1 |
| [[DB 3D Streaming and Moderation#tifoxr_3d_streaming_status|tifoxr_3d_streaming_status]] | 3D Streaming and Moderation | 5 | 0 | 1 | 0 |
| [[DB 3D Streaming and Moderation#tifoxr_3d_streaming_user_entry_log|tifoxr_3d_streaming_user_entry_log]] | 3D Streaming and Moderation | 9 | 3 | 0 | 0 |
| [[DB 3D Streaming and Moderation#tifoxr_3d_streaming_user_mtx|tifoxr_3d_streaming_user_mtx]] | 3D Streaming and Moderation | 11 | 3 | 0 | 1 |
| [[DB 3D Streaming and Moderation#tifoxr_3d_streaming_user_session|tifoxr_3d_streaming_user_session]] | 3D Streaming and Moderation | 14 | 4 | 2 | 0 |
| [[DB 3D Streaming and Moderation#tifoxr_3d_user_question|tifoxr_3d_user_question]] | 3D Streaming and Moderation | 14 | 6 | 1 | 0 |
| [[DB Payments#transaction_type|transaction_type]] | Payments | 5 | 0 | 1 | 2 |
| [[DB Games and Leaderboards#trivia_question_game|trivia_question_game]] | Games and Leaderboards | 7 | 2 | 1 | 0 |
| [[DB Games and Leaderboards#trivia_question_option|trivia_question_option]] | Games and Leaderboards | 7 | 2 | 0 | 0 |
| [[DB Users and Auth#user|user]] | Users and Auth | 22 | 6 | 43 | 67 |
| [[DB Users and Auth#user_age_range|user_age_range]] | Users and Auth | 6 | 0 | 1 | 0 |
| [[DB Users and Auth#user_badge|user_badge]] | Users and Auth | 6 | 2 | 0 | 0 |
| [[DB Metrics and Activity#user_booth_activity_mtx|user_booth_activity_mtx]] | Metrics and Activity | 12 | 4 | 0 | 2 |
| [[DB Spaces and Access#user_entity_map|user_entity_map]] | Spaces and Access | 8 | 2 | 0 | 0 |
| [[DB Metrics and Activity#user_event_activity_mtx|user_event_activity_mtx]] | Metrics and Activity | 10 | 3 | 1 | 1 |
| [[DB Users and Auth#user_exit_code|user_exit_code]] | Users and Auth | 5 | 0 | 3 | 0 |
| [[DB Shop Items and Orders#user_free_trial_grant_item|user_free_trial_grant_item]] | Shop Items and Orders | 11 | 4 | 0 | 12 |
| [[DB Games and Leaderboards#user_game_coins|user_game_coins]] | Games and Leaderboards | 5 | 1 | 0 | 0 |
| [[DB Games and Leaderboards#user_game_scoreboard|user_game_scoreboard]] | Games and Leaderboards | 15 | 3 | 0 | 4 |
| [[DB Games and Leaderboards#user_game_session|user_game_session]] | Games and Leaderboards | 11 | 3 | 0 | 3 |
| [[DB Games and Leaderboards#user_guess_player_game_clue|user_guess_player_game_clue]] | Games and Leaderboards | 7 | 2 | 0 | 0 |
| [[DB Shop Items and Orders#user_inventory|user_inventory]] | Shop Items and Orders | 8 | 0 | 0 | 5 |
| [[DB Games and Leaderboards#user_match_game_predictions|user_match_game_predictions]] | Games and Leaderboards | 7 | 2 | 0 | 0 |
| [[DB Payments#user_payment_method|user_payment_method]] | Payments | 9 | 3 | 0 | 0 |
| [[DB Rewards#user_reward|user_reward]] | Rewards | 13 | 4 | 0 | 0 |
| [[DB Users and Auth#user_session_management|user_session_management]] | Users and Auth | 18 | 5 | 4 | 18 |
| [[DB Metrics and Activity#user_space_activity_mtx|user_space_activity_mtx]] | Metrics and Activity | 11 | 4 | 0 | 1 |
| [[DB Users and Auth#user_type|user_type]] | Users and Auth | 5 | 0 | 1 | 11 |
| [[DB Content Media and Approval#workflow|workflow]] | Content Media and Approval | 7 | 2 | 1 | 0 |
