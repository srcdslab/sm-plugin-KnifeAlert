#if defined _knifealert_included
#endinput
#endif
#define _knifealert_included

/**
 * Called right after an Human knife a Zombie
 *
 * @param attacker       Attacker UserId
 * @param victim         Victim UserId
 * @param damage         Damage made by attacker to victim.
 * @noreturn
 */
forward void KnifeAlert_OnKnife(int attacker, int victim, int damage);

/**
 * Called right after an Human knife a Zombie
 *
 * @param attacker          Attacker UserId
 * @param Auth_attacker     Attacker SteamID  
 * @param victim            Victim UserId
 * @param pOldKnifer        Initial knifer UserId
 * @param Auth_OldKnifer    Initial knifer SteamID 
 * @noreturn
 */
forward void KnifeAlert_OnInfection(int attacker, char[] Auth_attacker, int victim, int pOldKnifer, char[] Auth_OldKnifer);

/**
 * Called right after an Human knife a Zombie
 *
 * @param attacker          Attacker UserId
 * @param Auth_attacker     Attacker SteamID  
 * @param victim            Victim UserId
 * @param Auth_OldKnifer    Initial knifer SteamID 
 * @noreturn
 */
forward void KnifeAlert_OnInfectionDisconnect(int attacker, char[] Auth_attacker, int victim, char[] Auth_OldKnifer);

public SharedPlugin __pl_sourcebanspp =
{
	name = "KnifeAlert",
	file = "KnifeAlert.smx",
	#if defined REQUIRE_PLUGIN
	required = 1
	#else
	required = 0
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_knifealert_SetNTVOptional()
{
    // No natives yet
}
#endif