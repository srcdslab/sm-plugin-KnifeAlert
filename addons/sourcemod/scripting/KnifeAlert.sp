#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multicolors>
#tryinclude <zombiereloaded>

bool g_bKnifeMode = false;
ConVar g_cvNotificationTime;
int g_iNotificationTime[MAXPLAYERS + 1];
int g_iClientUserId[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name         = "Knife Notifications",
	author       = "Obus + BotoX",
	description  = "Notify administrators when zombies have been knifed by humans.",
	version      = "2.4",
	url          = ""
};

public void OnPluginStart()
{
    g_cvNotificationTime = CreateConVar("sm_knifenotifytime", "5", "Amount of time to pass before a knifed zombie is considered \"not knifed\" anymore.", 0, true, 0.0, true, 60.0);

    AutoExecConfig(true);

    if(!HookEventEx("player_hurt", Event_PlayerHurt, EventHookMode_Pre))
        SetFailState("[Knife-Notifications] Failed to hook \"player_hurt\" event.");
}

public void OnAllPluginsLoaded()
{
	g_bKnifeMode = LibraryExists("KnifeMode");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "KnifeMode"))
		g_bKnifeMode = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "KnifeMode"))
		g_bKnifeMode = false;
}

public Action Event_PlayerHurt(Handle hEvent, const char[] name, bool dontBroadcast)
{
    if(g_bKnifeMode == true)
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

            if(damage < 35)
                return Plugin_Continue;

            GetClientAuthId(attacker, AuthId_Steam2, sAtkSID, sizeof(sAtkSID));
            GetClientAuthId(victim, AuthId_Steam2, sVictSID, sizeof(sVictSID));
            
            g_iClientUserId[victim] = GetClientUserId(attacker);
            LogMessage("%L knifed %L", attacker, victim);

            g_iNotificationTime[victim] = (GetTime() + GetConVarInt(g_cvNotificationTime));

            for(int i = 1; i <= MaxClients; i++)
            {
                if(IsClientConnected(i) && IsClientInGame(i) && (IsClientSourceTV(i) || GetAdminFlag(GetUserAdmin(i), Admin_Generic)))
                    CPrintToChat(i, "{green}[SM] {blue}%N {default}knifed {red}%N{default}.", attacker, victim);
            }
        }
    }
    else if(victim != attacker && GetClientTeam(attacker) == 2 && GetClientTeam(victim) == 3)
    {
        if(g_iNotificationTime[attacker] > GetTime())
        {
            pOldKnifer = GetClientOfUserId(g_iClientUserId[attacker]);
            if((victim != pOldKnifer))
            {    
                char sAtkAttackerName[MAX_NAME_LENGTH];
                GetClientAuthId(attacker, AuthId_Steam2, sAtkSID, sizeof(sAtkSID));
                
                char OldKniferSteamID[32];
                GetClientAuthId(pOldKnifer, AuthId_Steam2, OldKniferSteamID, sizeof(OldKniferSteamID));
    
                if(pOldKnifer != -1)
                {
                    GetClientName(pOldKnifer, sAtkAttackerName, sizeof(sAtkAttackerName));
                    LogMessage("%L killed %L (Recently knifed by %L)", attacker, victim, pOldKnifer);
                }
                else
                    LogMessage("%L killed %L (Recently knifed by a disconnected player [%s])", attacker, victim, OldKniferSteamID);
    
                #if defined _zr_included
                CPrintToChatAll("{green}[SM] {red}%N {green}(%s){default} infected {blue}%N{default} - knifed by {blue}%s{default}. {green}(%s)",
                    attacker, sAtkSID, victim, (pOldKnifer != -1) ? sAtkAttackerName : "a disconnected player", OldKniferSteamID);
                #else
                CPrintToChatAll("{green}[SM] {red}%N {green}(%s){default} killed {blue}%N{default} - knifed by {blue}%s{default}. {green}(%s)",
                    attacker, sAtkSID, victim, (pOldKnifer != -1) ? sAtkAttackerName : "a disconnected player", OldKniferSteamID);
                #endif
            }
        }
    }
    return Plugin_Continue;
}
