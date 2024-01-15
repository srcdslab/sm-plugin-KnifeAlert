#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <sourcemod>
#include <multicolors>

#undef REQUIRE_PLUGIN
#tryinclude <zombiereloaded>
#define REQUIRE_PLUGIN

bool g_Plugin_ZR = false;
bool g_bPlugin_KnifeMode = false;

ConVar g_cvNotificationTime;
ConVar g_cvKnifeModMsgs;
ConVar g_cvLog;

Handle g_hFwd_OnKnife = INVALID_HANDLE;
Handle g_hFwd_OnInfection = INVALID_HANDLE;
Handle g_hFwd_OnInfectionDisconnect = INVALID_HANDLE;

int g_iNotificationTime[MAXPLAYERS + 1];
int g_iClientUserId[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name         = "Knife Alert",
	author       = "Obus + BotoX",
	description  = "Notify administrators when zombies have been knifed by humans.",
	version      = "2.6.0",
	url          = "https://github.com/Rushaway/sm-plugin-KnifeAlert"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_hFwd_OnKnife = CreateGlobalForward("KnifeAlert_OnKnife", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hFwd_OnInfection = CreateGlobalForward("KnifeAlert_OnInfection", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_String);
	g_hFwd_OnInfectionDisconnect = CreateGlobalForward("KnifeAlert_OnInfectionDisconnect", ET_Ignore, Param_Cell, Param_Cell, Param_String);

	RegPluginLibrary("KnifeAlert");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_cvNotificationTime = CreateConVar("sm_knifenotifytime", "5", "Amount of time to pass before a knifed zombie is considered \"not knifed\" anymore.", 0, true, 0.0, true, 60.0);
	g_cvKnifeModMsgs     = CreateConVar("sm_knifemod_blocked", "1", "Block Alert messages when KnifeMode library is detected [0 = Print Alert | 1 = Block Alert]");
	g_cvLog			 	= CreateConVar("sm_knifealert_log", "1", "How should logs be notified (0 = Disabled, 1 = Enabled)");

	AutoExecConfig(true);

	if(!HookEventEx("player_hurt", Event_PlayerHurt, EventHookMode_Pre))
		SetFailState("[Knife-Alert] Failed to hook \"player_hurt\" event.");
}

public void OnAllPluginsLoaded()
{
	g_Plugin_ZR = LibraryExists("zombiereloaded");
	g_bPlugin_KnifeMode = LibraryExists("KnifeMode");

	LogMessage("[Knife-Alert] Capabilities: KnifeMode: %s - ZombieReloaded: %s",
		(g_bPlugin_KnifeMode ? "Loaded" : "Not loaded"),
		(g_Plugin_ZR ? "Loaded" : "Not loaded"));
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "KnifeMode"))
		g_bPlugin_KnifeMode = true;
	if (StrEqual(sName, "zombiereloaded"))
		g_Plugin_ZR = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if (StrEqual(sName, "KnifeMode"))
		g_bPlugin_KnifeMode = false;
	if (StrEqual(sName, "zombiereloaded"))
		g_Plugin_ZR = false;
}

public Action Event_PlayerHurt(Handle hEvent, const char[] name, bool dontBroadcast)
{
	if (g_bPlugin_KnifeMode && g_cvKnifeModMsgs.IntValue > 0)
		return Plugin_Continue;
	
	int victim, attacker, pOldKnifer = -1;
	char sWepName[64], sAtkSID[32], sVictSID[32];
	GetEventString(hEvent, "weapon", sWepName, sizeof(sWepName));

	if((victim = GetClientOfUserId(GetEventInt(hEvent, "userid"))) == 0)
		return Plugin_Continue;

	if((attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"))) == 0)
		return Plugin_Continue;

	if(!IsClientInGame(victim) || !IsPlayerAlive(victim))
		return Plugin_Continue;

	if(!IsClientInGame(attacker) || !IsPlayerAlive(attacker))
		return Plugin_Continue;
	
	if(victim != attacker && GetClientTeam(victim) == 2 && GetClientTeam(attacker) == 3)
	{
		if(StrEqual(sWepName, "knife"))
		{
			int damage = GetEventInt(hEvent, "dmg_health");

			if(damage < 15) // Minimum dmg for victim without helmet is 17 on CS:S
				return Plugin_Continue;

			GetClientAuthId(attacker, AuthId_Steam2, sAtkSID, sizeof(sAtkSID));
			GetClientAuthId(victim, AuthId_Steam2, sVictSID, sizeof(sVictSID));
			
			g_iClientUserId[victim] = GetClientUserId(attacker);

			g_iNotificationTime[victim] = (GetTime() + GetConVarInt(g_cvNotificationTime));

			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientConnected(i) && IsClientInGame(i) && (IsClientSourceTV(i) || GetAdminFlag(GetUserAdmin(i), Admin_Generic)))
					CPrintToChat(i, "{green}[SM] {blue}%N {default}knifed {red}%N{default}. (-%d HP)", attacker, victim, damage);
			}

			if (g_cvLog.IntValue > 0)
				LogMessage("%L Knifed %L", attacker, victim);
			
			// Start forward call
			Call_StartForward(g_hFwd_OnKnife);
			Call_PushCell(attacker);
			Call_PushCell(victim);
			Call_PushCell(damage);
			Call_Finish();
		}
	}
	else if(victim != attacker && GetClientTeam(attacker) == 2 && GetClientTeam(victim) == 3)
	{
		if(g_iNotificationTime[attacker] > GetTime())
		{
			pOldKnifer = GetClientOfUserId(g_iClientUserId[attacker]);
			if((victim != pOldKnifer))
			{    
				char OldKniferSteamID[32];
				GetClientAuthId(attacker, AuthId_Steam2, sAtkSID, sizeof(sAtkSID));
				GetClientAuthId(pOldKnifer, AuthId_Steam2, OldKniferSteamID, sizeof(OldKniferSteamID));
	
				if(pOldKnifer != -1)
				{
					CPrintToChatAll("{green}[SM]{red} %N{green} ({lightgreen}%s{green}){default} %s{blue} %N{default}.",
						attacker, sAtkSID, g_Plugin_ZR ? "infected" : "killed", victim);
					CPrintToChatAll("{green}[SM]{default} Knifed by{blue} %N{default}.", pOldKnifer);

					if (g_cvLog.IntValue > 0)
						LogMessage("%L %s %L (Recently knifed by %L)", attacker, g_Plugin_ZR ? "infected" : "killed", victim, pOldKnifer);
				
					// Start forward call
					Call_StartForward(g_hFwd_OnInfection);
					Call_PushCell(attacker);
					Call_PushString(sAtkSID);
					Call_PushCell(victim);
					Call_PushCell(pOldKnifer);
					Call_PushString(OldKniferSteamID);
					Call_Finish();
				}
				else
				{
					CPrintToChatAll("{green}[SM]{red} %N{green} ({lightgreen}%s{green}) %s{blue} %N{default}.", attacker, sAtkSID, g_Plugin_ZR ? "infected" : "killed", victim);
					CPrintToChatAll("{green}[SM]{default} Knifed by a disconnected player. {lightgreen}[%s]", OldKniferSteamID);

					if (g_cvLog.IntValue > 0)
						LogMessage("%L %s %L (Recently knifed by a disconnected player [%s])", attacker, g_Plugin_ZR ? "Infected" : "Killed", victim, OldKniferSteamID);
				
					// Start forward call
					Call_StartForward(g_hFwd_OnInfectionDisconnect);
					Call_PushCell(attacker);
					Call_PushString(sAtkSID);
					Call_PushCell(victim);
					Call_PushString(OldKniferSteamID);
					Call_Finish();
				}
			}
		}
	}
	return Plugin_Continue;
}