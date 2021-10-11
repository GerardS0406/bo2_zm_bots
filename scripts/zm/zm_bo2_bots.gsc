#include maps/mp/zombies/_zm_utility;
#include common_scripts/utility;
#include maps/mp/_utility;
#include scripts/zm/zm_bo2_bots_combat;

init()
{
	bot_set_skill();
	flag_wait("initial_blackscreen_passed");
	if(!isdefined(level.using_bot_weapon_logic))
		level.using_bot_weapon_logic = 1;
	bot_amount = GetDvarIntDefault("bo2_zm_bots_count", 0);
	if(bot_amount > (8-get_players().size))
		bot_amount = 8 - get_players().size;
	for(i=0;i<bot_amount;i++)
		spawn_bot();
}

bot_set_skill()
{
	setdvar( "bot_MinDeathTime", "250" );
	setdvar( "bot_MaxDeathTime", "500" );
	setdvar( "bot_MinFireTime", "100" );
	setdvar( "bot_MaxFireTime", "250" );
	setdvar( "bot_PitchUp", "-5" );
	setdvar( "bot_PitchDown", "10" );
	setdvar( "bot_Fov", "160" );
	setdvar( "bot_MinAdsTime", "3000" );
	setdvar( "bot_MaxAdsTime", "5000" );
	setdvar( "bot_MinCrouchTime", "100" );
	setdvar( "bot_MaxCrouchTime", "400" );
	setdvar( "bot_TargetLeadBias", "2" );
	setdvar( "bot_MinReactionTime", "40" );
	setdvar( "bot_MaxReactionTime", "70" );
	setdvar( "bot_StrafeChance", "1" );
	setdvar( "bot_MinStrafeTime", "3000" );
	setdvar( "bot_MaxStrafeTime", "6000" );
	setdvar( "scr_help_dist", "512" );
	setdvar( "bot_AllowGrenades", "1" );
	setdvar( "bot_MinGrenadeTime", "1500" );
	setdvar( "bot_MaxGrenadeTime", "4000" );
	setdvar( "bot_MeleeDist", "70" );
	setdvar( "bot_YawSpeed", "4" );
	setdvar( "bot_SprintDistance", "256" );
}

bot_get_closest_enemy( origin )
{
	enemies = get_round_enemy_array();
	enemies = arraysort( enemies, origin );
	if ( enemies.size >= 1 )
	{
		return enemies[ 0 ];
	}
	return undefined;
}

spawn_bot()
{
	bot = addtestclient();
	bot waittill("spawned_player");
	bot thread maps/mp/zombies/_zm::spawnspectator();
	if ( isDefined( bot ) )
	{
		bot.pers[ "isBot" ] = 1;
		bot thread onspawn();
	}
	wait 1;
	bot [[ level.spawnplayer ]]();
}

bot_spawn()
{
	self bot_spawn_init();
	self.bot_first_spawn = 1;
	self thread bot_main();
}

bot_spawn_init()
{
	self SwitchToWeapon("m1911_zm");
	self SetSpawnWeapon("m1911_zm");
	time = getTime();
	if ( !isDefined( self.bot ) )
	{
		self.bot = spawnstruct();
		self.bot.threat = spawnstruct();
	}
	self.bot.glass_origin = undefined;
	self.bot.ignore_entity = [];
	self.bot.previous_origin = self.origin;
	self.bot.time_ads = 0;
	self.bot.update_c4 = time + randomintrange( 1000, 3000 );
	self.bot.update_crate = time + randomintrange( 1000, 3000 );
	self.bot.update_crouch = time + randomintrange( 1000, 3000 );
	self.bot.update_failsafe = time + randomintrange( 1000, 3000 );
	self.bot.update_idle_lookat = time + randomintrange( 1000, 3000 );
	self.bot.update_killstreak = time + randomintrange( 1000, 3000 );
	self.bot.update_lookat = time + randomintrange( 1000, 3000 );
	self.bot.update_objective = time + randomintrange( 1000, 3000 );
	self.bot.update_objective_patrol = time + randomintrange( 1000, 3000 );
	self.bot.update_patrol = time + randomintrange( 1000, 3000 );
	self.bot.update_toss = time + randomintrange( 1000, 3000 );
	self.bot.update_launcher = time + randomintrange( 1000, 3000 );
	self.bot.update_weapon = time + randomintrange( 1000, 3000 );
	self.bot.think_interval = 0.1;
	self.bot.fov = -0.9396;
	self.bot.threat.entity = undefined;
	self.bot.threat.position = ( 0, 0, 0 );
	self.bot.threat.time_first_sight = 0;
	self.bot.threat.time_recent_sight = 0;
	self.bot.threat.time_aim_interval = 0;
	self.bot.threat.time_aim_correct = 0;
	self.bot.threat.update_riotshield = 0;
}

bot_main()
{
	self endon( "death" );
	self endon( "disconnect" );
	level endon( "game_ended" );

	self thread bot_wakeup_think();
	self thread bot_damage_think();
	self thread bot_give_ammo();
	for ( ;; )
	{
		self waittill( "wakeup", damage, attacker, direction );
		if( self isremotecontrolling())
		{
			continue;
		}
		else
		{
			self bot_combat_think( damage, attacker, direction );
			self bot_update_follow_host();
			self bot_update_lookat();
			if(is_true(level.using_bot_weapon_logic))
			{
				self bot_buy_wallbuy();
				self bot_pack_gun();
			}
			//self bot_buy_box();
			//HIGH PRIORITY: PICKUP POWERUP
			//WHEN GIVING BOTS WEAPONS, YOU MUST USE setspawnweapon() FUNCTION!!!
			//ADD OTHER NON-COMBAT RELATED TASKS HERE (BUYING GUNS, CERTAIN GRIEF MECHANICS)
			//ANYTHING THAT CAN BE DONE WHILE THE BOT IS NOT THREATENED BY A ZOMBIE
		}	
	}
}

bot_pack_gun()
{
	if(level.round_number <= 1)
		return;
	if(!self bot_should_pack())
		return;
	machines = GetEntArray("zombie_vending", "targetname");
	foreach(pack in machines)
	{
		if(pack.script_noteworthy != "specialty_weapupgrade")
			continue;
		if(Distance(pack.origin, self.origin) < 400 && self.score >= 5000 && nodescanpath( bot_nearest_node(self.origin), bot_nearest_node(pack.origin)))
		{
			self maps/mp/zombies/_zm_score::minus_to_player_score(5000);
			weapon = self GetCurrentWeapon();
			upgrade_name = maps/mp/zombies/_zm_weapons::get_upgrade_weapon( weapon );
			self TakeAllWeapons();
			self GiveWeapon(upgrade_name);
			self SetSpawnWeapon(upgrade_name);
			return;
		}
	}
}

bot_buy_wallbuy()
{
	self endon("death");
	self endon("disconnect");
	level endon("end_game");
	if(self hasgoal("weaponBuy"))
		return;
	if(self HasWeapon("mp5k_zm") || self HasWeapon("pdw57_zm"))
		return;
	weapon = self GetCurrentWeapon();
	weaponToBuy = undefined;
	wallbuys = array_randomize(level._spawned_wallbuys);
	foreach(wallbuy in wallbuys)
	{
		if(Distance(wallbuy.origin, self.origin) < 400 && wallbuy.trigger_stub.cost <= self.score && bot_best_gun(wallbuy.zombie_weapon_upgrade, weapon) && nodescanpath( bot_nearest_node(self.origin), bot_nearest_node(wallbuy.origin)) && weapon != wallbuy.zombie_weapon_upgrade)
		{
			weaponToBuy = wallbuy;
			break;
		}
	}
	if(!isdefined(weaponToBuy))
		return;
	self AddGoal(weaponToBuy.origin, 75, 2, "weaponBuy");
	while(!self AtGoal("weaponBuy") && !Distance(self.origin, weaponToBuy.origin) < 100)
	{
		wait 1;
	}
	self cancelgoal("weaponBuy");
	self maps/mp/zombies/_zm_score::minus_to_player_score( weaponToBuy.trigger_stub.cost );
	self TakeAllWeapons();
	self GiveWeapon(weaponToBuy.zombie_weapon_upgrade);
	self SetSpawnWeapon(weaponToBuy.zombie_weapon_upgrade);
	IPrintLn("Bot Bought Weapon");
	
}

bot_should_pack()
{
	if(maps/mp/zombies/_zm_weapons::can_upgrade_weapon(self GetCurrentWeapon()))
		return 1;
	return 0;
}

bot_best_gun(buyingweapon, currentweapon)
{
	if(buyingweapon == "mp5_zm" || buyingweapon == "pdw57_zm")
		return 1;
	if(maps/mp/zombies/_zm_weapons::get_weapon_cost(buyingweapon) > maps/mp/zombies/_zm_weapons::get_weapon_cost(currentweapon))
		return 1;
	return 0;
}

bot_wakeup_think()
{
	self endon( "death" );
	self endon( "disconnect" );
	level endon( "game_ended" );
	for ( ;; )
	{
		wait self.bot.think_interval;
		self notify( "wakeup" );
	}
}

bot_damage_think()
{
	self notify( "bot_damage_think" );
	self endon( "bot_damage_think" );
	self endon( "disconnect" );
	level endon( "game_ended" );
	for ( ;; )
	{
		self waittill( "damage", damage, attacker, direction, point, mod, unused1, unused2, unused3, weapon, flags, inflictor );
		self.bot.attacker = attacker;
		self notify( "wakeup", damage, attacker, direction );
	}
}

bot_give_ammo()
{
	self endon( "disconnect" );
	self endon( "death" );
	level endon( "game_ended" );
	for(;;)
	{
		primary_weapons = self GetWeaponsListPrimaries();
		j=0;
		while(j<primary_weapons.size)
		{
			self GiveMaxAmmo(primary_weapons[ j ]);
			j++;
		}
		wait 1;
	}
}

onspawn()
{
	self endon("disconnect");
	level endon("end_game");
	while(1)
	{
		self waittill("spawned_player");
		self thread bot_perks();
		self thread bot_spawn();
	}
}

bot_perks()
{
	self endon("disconnect");
	self endon("death");
	wait 1;
	while(1)
	{
		self SetNormalHealth(250);
		self SetmaxHealth(250);
		self SetPerk("specialty_flakjacket");
		self SetPerk("specialty_rof");
		self SetPerk("specialty_fastreload");
		self waittill("player_revived");
	}
}

bot_update_follow_host()
{
	//goal = self GetGoal("wander");
	//if(distance(goal, self.origin) > 100)
	//	return;
	//if(distance(self.origin, get_players[0].origin) > 3000)
	self AddGoal(get_players()[0].origin, 200, 1, "wander");
	//self lookat(get_players()[0].origin);
	//else
	//	self AddGoal()	
}

bot_update_lookat()
{
	path = 0;
	if ( isDefined( self getlookaheaddir() ) )
	{
		path = 1;
	}
	if ( !path && getTime() > self.bot.update_idle_lookat )
	{
		origin = bot_get_look_at();
		if ( !isDefined( origin ) )
		{
			return;
		}
		self lookat( origin + vectorScale( ( 0, 0, 1 ), 16 ) );
		self.bot.update_idle_lookat = getTime() + randomintrange( 1500, 3000 );
	}
	else if ( path && self.bot.update_idle_lookat > 0 )
	{
		self clearlookat();
		self.bot.update_idle_lookat = 0;
	}
}

bot_get_look_at()
{
	enemy = bot_get_closest_enemy( self.origin );
	if ( isDefined( enemy ) )
	{
		node = getvisiblenode( self.origin, enemy.origin );
		if ( isDefined( node ) && distancesquared( self.origin, node.origin ) > 1024 )
		{
			return node.origin;
		}
	}
	spawn = self getgoal( "wander" );
	if ( isDefined( spawn ) )
	{
		node = getvisiblenode( self.origin, spawn );
	}
	if ( isDefined( node ) && distancesquared( self.origin, node.origin ) > 1024 )
	{
		return node.origin;
	}
	return undefined;
}

bot_update_weapon()
{
	weapon = self GetCurrentWeapon();
	primaries = self getweaponslistprimaries();
	foreach ( primary in primaries )
	{
		if ( primary != weapon )
		{
			self switchtoweapon( primary );
			return;
		}
		i++;
	}
}

bot_update_failsafe()
{
	time = getTime();
	if ( ( time - self.spawntime ) < 7500 )
	{
		return;
	}
	if ( time < self.bot.update_failsafe )
	{
		return;
	}
	if ( !self atgoal() && distance2dsquared( self.bot.previous_origin, self.origin ) < 256 )
	{
		nodes = getnodesinradius( self.origin, 512, 0 );
		nodes = array_randomize( nodes );
		nearest = bot_nearest_node( self.origin );
		failsafe = 0;
		if ( isDefined( nearest ) )
		{
			i = 0;
			while ( i < nodes.size )
			{
				if ( !bot_failsafe_node_valid( nearest, nodes[ i ] ) )
				{
					i++;
					continue;
				}
				else
				{
					self botsetfailsafenode( nodes[ i ] );
					wait 0.5;
					self.bot.update_idle_lookat = 0;
					self bot_update_lookat();
					self cancelgoal( "enemy_patrol" );
					self wait_endon( 4, "goal" );
					self botsetfailsafenode();
					self bot_update_lookat();
					failsafe = 1;
					break;
				}
				i++;
			}
		}
		else if ( !failsafe && nodes.size )
		{
			node = random( nodes );
			self botsetfailsafenode( node );
			wait 0.5;
			self.bot.update_idle_lookat = 0;
			self bot_update_lookat();
			self cancelgoal( "enemy_patrol" );
			self wait_endon( 4, "goal" );
			self botsetfailsafenode();
			self bot_update_lookat();
		}
	}
	self.bot.update_failsafe = getTime() + 3500;
	self.bot.previous_origin = self.origin;
}

bot_failsafe_node_valid( nearest, node )
{
	if ( isDefined( node.script_noteworthy ) )
	{
		return 0;
	}
	if ( ( node.origin[ 2 ] - self.origin[ 2 ] ) > 18 )
	{
		return 0;
	}
	if ( nearest == node )
	{
		return 0;
	}
	if ( !nodesvisible( nearest, node ) )
	{
		return 0;
	}
	if ( isDefined( level.spawn_all ) && level.spawn_all.size > 0 )
	{
		spawns = arraysort( level.spawn_all, node.origin );
	}
	else if ( isDefined( level.spawnpoints ) && level.spawnpoints.size > 0 )
	{
		spawns = arraysort( level.spawnpoints, node.origin );
	}
	else if ( isDefined( level.spawn_start ) && level.spawn_start.size > 0 )
	{
		spawns = arraycombine( level.spawn_start[ "allies" ], level.spawn_start[ "axis" ], 1, 0 );
		spawns = arraysort( spawns, node.origin );
	}
	else
	{
		return 0;
	}
	goal = bot_nearest_node( spawns[ 0 ].origin );
	if ( isDefined( goal ) && findpath( node.origin, goal.origin, undefined, 0, 1 ) )
	{
		return 1;
	}
	return 0;
}

bot_nearest_node( origin )
{
	node = getnearestnode( origin );
	if ( isDefined( node ) )
	{
		return node;
	}
	nodes = getnodesinradiussorted( origin, 256, 0, 256 );
	if ( nodes.size )
	{
		return nodes[ 0 ];
	}
	return undefined;
}
