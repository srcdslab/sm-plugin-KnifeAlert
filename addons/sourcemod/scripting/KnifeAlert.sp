#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
#include <sourcemod>
#include <multicolors>
#tryinclude <zombiereloaded>
#tryinclude <discordWebhookAPI>

#define WEBHOOK_URL_MAX_SIZE	1000

bool g_Plugin_ZR = false;
bool g_bPlugin_KnifeMode = false;

ConVar g_cvNotificationTime;
ConVar g_cvKnifeModMsgs;
ConVar g_cvLogType;
#if defined _discordWebhookAPI_included_
ConVar g_cvWebhook;
ConVar g_cvWebhookRetry;
#endif

int g_iNotificationTime[MAXPLAYERS + 1];
int g_iClientUserId[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name         = "Knife Alert",
	author       = "Obus + BotoX",
	description  = "Notify administrators when zombies have been knifed by humans.",
	version      = "2.5.0",
	url          = ""
};

public void OnPluginStart()
{
	g_cvNotificationTime = CreateConVar("sm_knifenotifytime", "5", "Amount of time to pass before a knifed zombie is considered \"not knifed\" anymore.", 0, true, 0.0, true, 60.0);
	g_cvKnifeModMsgs     = CreateConVar("sm_knifemod_blocked", "1", "Block Alert messages when KnifeMode library is detected [0 = Print Alert | 1 = Block Alert]");
	g_cvLogType			 = CreateConVar("sm_knifealert_log_type", "0", "How should logs be notified (-1 = Disabled, 0 = Server, 1 = Discord)");
#if defined _discordWebhookAPI_included_
	g_cvWebhook 		 = CreateConVar("sm_knifealert_webhook", "", "The webhook URL of your Discord channel.", FCVAR_PROTECTED);
	g_cvWebhookRetry 	 = CreateConVar("sm_knifealert_webhook_retry", "3", "Number of retries if webhook fails.", FCVAR_PROTECTED);
#endif

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

			char sMessage[1024];
			Format(sMessage, sizeof(sMessage), "%L Knifed %L", attacker, victim);

			if (g_cvLogType.IntValue == 0)
				LogMessage("%s", sMessage);
		#if defined _discordWebhookAPI_included_
			if (g_cvLogType.IntValue >= 1)
				PrepareDiscord_Message(sMessage);
		#endif

			g_iNotificationTime[victim] = (GetTime() + GetConVarInt(g_cvNotificationTime));

			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientConnected(i) && IsClientInGame(i) && (IsClientSourceTV(i) || GetAdminFlag(GetUserAdmin(i), Admin_Generic)))
					CPrintToChat(i, "{green}[SM] {blue}%N {default}knifed {red}%N{default}. (-%d HP)", attacker, victim, damage);
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
				char sMessage[1024];
				char sAtkAttackerName[MAX_NAME_LENGTH];
				GetClientAuthId(attacker, AuthId_Steam2, sAtkSID, sizeof(sAtkSID));
				
				char OldKniferSteamID[32];
				GetClientAuthId(pOldKnifer, AuthId_Steam2, OldKniferSteamID, sizeof(OldKniferSteamID));
	
				if(pOldKnifer != -1)
				{
					GetClientName(pOldKnifer, sAtkAttackerName, sizeof(sAtkAttackerName));
					Format(sMessage, sizeof(sMessage), "%L %s %L (Recently knifed by %L)", attacker, g_Plugin_ZR ? "infected" : "killed", victim, pOldKnifer);

					if (g_cvLogType.IntValue == 0)
						LogMessage("%s", sMessage);
				#if defined _discordWebhookAPI_included_
					if (g_cvLogType.IntValue >= 1)
						PrepareDiscord_Message(sMessage);
				#endif

					CPrintToChatAll("{green}[SM]{red} %N{green} ({lightgreen}%s{green}){default} %s{blue} %N{default}.",
						attacker, sAtkSID, g_Plugin_ZR ? "infected" : "killed", victim);
					CPrintToChatAll("{green}[SM]{default} Knifed by{blue} %s{default}.", sAtkAttackerName);
				}
				else
				{
					Format(sMessage, sizeof(sMessage), "%L %s %L (Recently knifed by a disconnected player [%s])",
						attacker, g_Plugin_ZR ? "Infected" : "Killed", victim, OldKniferSteamID);
					
					if (g_cvLogType.IntValue == 0)
						LogMessage("%s", sMessage);
				#if defined _discordWebhookAPI_included_
					if (g_cvLogType.IntValue >= 1)
						PrepareDiscord_Message(sMessage);
				#endif

					CPrintToChatAll("{green}[SM]{red} %N{green} ({lightgreen}%s{green}) %s{blue} %N{default}.",
						attacker, sAtkSID, g_Plugin_ZR ? "infected" : "killed", victim);
					CPrintToChatAll("{green}[SM]{default} Knifed by a disconnected player. {lightgreen}[%s]", OldKniferSteamID);
				}
			}
		}
	}
	return Plugin_Continue;
}
#if defined _discordWebhookAPI_included_
stock void PrepareDiscord_Message(const char[] message)
{
	char sWebhookURL[WEBHOOK_URL_MAX_SIZE];
	g_cvWebhook.GetString(sWebhookURL, sizeof sWebhookURL);
	if(!sWebhookURL[0])
	{
		LogError("[Knife-Alert] No webhook found or specified.");
		return;
	}

	char sMessage[4096];
	char sTime[64];
	int iTime = GetTime();
	FormatTime(sTime, sizeof(sTime), "%m/%d/%Y @ %H:%M:%S", iTime);

	char currentMap[PLATFORM_MAX_PATH];
	GetCurrentMap(currentMap, sizeof(currentMap));

	Format(sMessage, sizeof(sMessage), "*%s (CT: %d | T: %d) %s* ```%s```", currentMap, GetTeamScore(3), GetTeamScore(2), sTime, message);

	if(StrContains(sMessage, "\"") != -1)
		ReplaceString(sMessage, sizeof(sMessage), "\"", "");

	SendWebHook(sMessage, sWebhookURL);
}

stock void SendWebHook(char sMessage[4096], char sWebhookURL[WEBHOOK_URL_MAX_SIZE])
{
	Webhook webhook = new Webhook(sMessage);

	DataPack pack = new DataPack();
	pack.WriteString(sMessage);
	pack.WriteString(sWebhookURL);

	webhook.Execute(sWebhookURL, OnWebHookExecuted, pack);
	delete webhook;
}

public void OnWebHookExecuted(HTTPResponse response, DataPack pack)
{
	static int retries = 0;

	pack.Reset();

	char sMessage[4096];
	pack.ReadString(sMessage, sizeof(sMessage));

	char sWebhookURL[WEBHOOK_URL_MAX_SIZE];
	pack.ReadString(sWebhookURL, sizeof(sWebhookURL));

	delete pack;

	if (response.Status != HTTPStatus_OK)
	{
		if (retries < g_cvWebhookRetry.IntValue)
		{
			PrintToServer("[Knife-Alert] Failed to send the webhook. Resending it .. (%d/%d)", retries, g_cvWebhookRetry.IntValue);

			SendWebHook(sMessage, sWebhookURL);
			retries++;
			return;
		}
		else
		{
			LogError("[Knife-Alert] Failed to send the webhook after %d retries, aborting.", retries);
		}
	}

	retries = 0;
}
#endif
