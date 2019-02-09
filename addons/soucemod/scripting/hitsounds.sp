#include <sdktools>
#include <cstrike>

#pragma newdecls required
#define PLUGIN_VERSION "1.0"
public Plugin myinfo =
{
	name = "Hitsounds",
	author = "JPlays",
	description = "Hitsound plugin!",
	version = PLUGIN_VERSION,
	url = "http://jplays.tk/"
};

bool HitsoundsEnabled[MAXPLAYERS + 1];

ConVar cvarDisplayDamage;
ConVar cvarRules;
ConVar cvarFriendlyFire;

ArrayList aSmokes = null;

public void OnPluginStart()
{
	aSmokes = new ArrayList(3);
	RegConsoleCmd("sm_hitsound", Command_togglesounds);
	RegConsoleCmd("sm_hitsounds", Command_togglesounds);
	
	HookEvent("player_hurt", Event_Hurt);
	HookEvent("smokegrenade_detonate", Event_SmokeDetonate);
	HookEvent("smokegrenade_expired", Event_SmokeRemoved);
	HookEvent("round_start", Event_RoundStart);
	
	CreateConVar("sm_hitsoundscsgo_version", PLUGIN_VERSION, "Donut Touch", FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_SPONLY);
	cvarDisplayDamage = CreateConVar("sm_hitsounds_displaydamage", "1", "Display damage done to attacker", _, true, 0.0, true, 1.0);
	cvarRules = CreateConVar("sm_hitsounds_rules", "1", "Only play hitsound if target is visible", _, true, 0.0, true, 1.0);
	cvarFriendlyFire = CreateConVar("sm_hitsounds_friendlyfire", "0", "Play hitsound when injuring teammates", _, true, 0.0, true, 1.0);
}

public void OnMapEnd()
{
	aSmokes.Clear();
}

public void OnClientConnected(int client)
{
	HitsoundsEnabled[client] = true;
}
public Action Command_togglesounds(int client, int args)
{
	if (!client) 
	{
		return Plugin_Continue;
	}
	
	Menu menu = new Menu(Menu_Handler);
	menu.SetTitle("Menu dos Hitsounds");
	menu.AddItem("1", "Ativar Hitsounds", HitsoundsEnabled[client] ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	menu.AddItem("2", "Desativar Hitsounds", HitsoundsEnabled[client] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	menu.ExitButton = true;
	menu.Display(client, 20);
	
	return Plugin_Handled;
}

public int Menu_Handler(Menu menu, MenuAction action, int client, int choice)
{
	if(action == MenuAction_Select)
	{
		switch(choice)
		{
			case 0:
			{
				HitsoundsEnabled[client] = true;
			}
			case 1:
			{
				HitsoundsEnabled[client] = false;
			}
		}
		ReplyToCommand(client, "\x01You've %sabled hitsounds.", HitsoundsEnabled[client] ? "en" : "dls");
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}


public Action Event_Hurt(Event event, const char[] name, bool dontBroadcast)
{
	DataPack data; // Delay it to a frame later. If we use IsPlayerAlive(victim) here, it would always return true.
	char weapon[64];
	event.GetString("weapon", weapon, sizeof(weapon));
	CreateDataTimer(0.0, Timer_Hitsound, data, TIMER_FLAG_NO_MAPCHANGE);
	
	data.WriteCell(event.GetInt("attacker"));
	data.WriteCell(event.GetInt("userid"));
	data.WriteCell(event.GetInt("dmg_health"));	
	data.WriteCell(event.GetInt("dmg_armor"));
	data.WriteCell(event.GetInt("hitgroup"));
	data.WriteString(weapon);
	data.Reset();
	
}

public Action Timer_Hitsound(Handle timer, DataPack data)
{
	int attacker	= GetClientOfUserId(ReadPackCell(data));
	int victim		= GetClientOfUserId(ReadPackCell(data));
	int damage		= ReadPackCell(data);
	int dmg_armor 	= ReadPackCell(data);
	int hitgroup 	= ReadPackCell(data);
	
	char weapon[64];
	ReadPackString(data, weapon, sizeof(weapon));
	
	if (!HitsoundsEnabled[attacker]) return;
	if (attacker <= 0 || attacker > MaxClients || victim <= 0 || victim > MaxClients || attacker == victim) return;
	if (GetClientTeam(attacker) == GetClientTeam(victim) && !GetConVarBool(cvarFriendlyFire)) return;
	if (IsPlayerAlive(victim) && GetConVarBool(cvarRules))
	{
		int numSmokes = aSmokes.Length, closest = -1;
		float closestdist = 600.0;
		if (numSmokes)
		{
			float VictimPos[3];
			GetClientAbsOrigin(victim, VictimPos);
			for (int i = 0; i < numSmokes; i++)
			{
				float thisPos[3];
				aSmokes.GetArray(i, thisPos, 3);
				float dist = GetVectorDistance(VictimPos, thisPos);
				if (dist > closestdist) continue;
				closest = i, closestdist = dist;
			}
			if (closest > -1) return;
		}
		if (!HasClearSight(attacker, victim)) return;
	}
	ClientCommand(attacker, "playgamesound training/bell_normal.wav");
	
	if (GetConVarBool(cvarDisplayDamage))
	{
		char hitgroup_string[64];
		GetHitGroupName(hitgroup, hitgroup_string);
		PrintHintText(attacker, "<font color='#993300'>%s</font>. \nHealth: <font color='#336600'>-%i</font> | Armor: <font color='#0066CC'>-%i</font>", hitgroup_string, damage, dmg_armor);
	}
}

void GetHitGroupName(int hitgroup, char name[64])
{
	switch(hitgroup)
	{
		case 0:
		{
			strcopy(name, sizeof(name), ""); // Caso seja inválido, portanto não colocamos;
		}
		case 1:
		{
			strcopy(name, sizeof(name), "Cabeça");
		}
		case 2:
		{
			strcopy(name, sizeof(name), "Peito");
		}
		case 3:
		{
			strcopy(name, sizeof(name), "Estômago");
		}
		case 4:
		{
			strcopy(name, sizeof(name), "Braço Esquerdo");
		}
		case 5:
		{
			strcopy(name, sizeof(name), "Braço Direito");
		}
		case 6:
		{
			strcopy(name, sizeof(name), "Perna Esquerda");
		}
		case 7:
		{
			strcopy(name, sizeof(name), "Perna Direita");
		}
	}
}

public Action Event_SmokeDetonate(Event event, const char[] name, bool dontBroadcast)
{
	float Pos[3];
	Pos[0] = event.GetFloat("x");
	Pos[1] = event.GetFloat("y");
	Pos[2] = event.GetFloat("z");
	
	aSmokes.PushArray(Pos, 3);
}

public Action Event_SmokeRemoved(Event event, const char[] name, bool dontBroadcast)
{
	float Pos[3];
	Pos[0] = event.GetFloat("x");
	Pos[1] = event.GetFloat("y");
	Pos[2] = event.GetFloat("z");
	int numSmokes = GetArraySize(aSmokes), closest = -1; 
	float closestdist = 400.0;
	for (int i = 0; i < numSmokes; i++)
	{
		float thisPos[3];
		GetArrayArray(aSmokes, i, thisPos, 3);
		float dist = GetVectorDistance(Pos, thisPos);
		if (dist > closestdist) continue;
		closest = i, closestdist = dist;
	}
	if (closest == -1) return;
	RemoveFromArray(aSmokes, closest);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	aSmokes.Clear();
}
	
stock int HasClearSight(int client, int target)
{
	float ClientPos[3], TargetPos[3], Result[3];
	GetClientEyePosition(client, ClientPos);
	GetClientAbsOrigin(target, TargetPos);
	TargetPos[2] += 32.0;
	
	MakeVectorFromPoints(ClientPos, TargetPos, Result);
	GetVectorAngles(Result, Result);
	
	TR_TraceRayFilter(ClientPos, Result, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelf, client);
	return target == TR_GetEntityIndex();
}
public bool TraceRayDontHitSelf(int Ent, int Mask, any Hit) 
{
	return Ent != Hit;
}