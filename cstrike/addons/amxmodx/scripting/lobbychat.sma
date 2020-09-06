#include <amxmodx>
#include <amxmisc>

#define PLUGIN "Lobby Chat"
#define VERSION "2.0"
#define AUTHOR "Roccoxx"

#pragma semicolon 1

#define IsPlayer(%0)            (1 <= %0 <= MAX_PLAYERS)

#define GetPlayerBit(%0,%1)     (IsPlayer(%1) && (%0 & (1 << (%1 & 31))))
#define SetPlayerBit(%0,%1)     (IsPlayer(%1) && (%0 |= (1 << (%1 & 31))))
#define ClearPlayerBit(%0,%1)   (IsPlayer(%1) && (%0 &= ~(1 << (%1 & 31))))
#define SwitchPlayerBit(%0,%1)  (IsPlayer(%1) && (%0 ^= (1 << (%1 & 31))))

//============================ Configuration ====================================
const ADMIN_FLAG = ADMIN_BAN; // admin lobby flag
#define FILE_LOBBY "lobby.ini" // Lobby Names
#define FILE_LANG "lobby.txt" // Lobby Language

/* CVARS:
lobby_admin > admins can create lobbies (1 enabled | 0 disabled)
lobby_maxmembers > max members in lobby
lobby_maxlobby > max lobbies limit
*/

new const szLobbyMenuCommand[] = "/lobby"; // to open the lobby menu in say
new const szLobbyCreateCommand[] = "/create_lobby"; // to create a lobby with new name

const MAX_LOBBY_LENGHT_NAME = 60; // MAX LOBBY LENGHT NAME
// =========================== EDIT END ===================

const MAX_LOBBIES = 32; // 1 LOBBY PER PLAYER IS THE LIMIT

new g_iLobbySelected[33], g_iOwnerLobbyIndex[33], g_szInvitation[33][32];

new g_iIsConnected, g_iPlayerLobby[MAX_LOBBIES], g_iIsOwner;

new g_iLobbiesCount;

enum _:LOBBY_DATA
{
    LOBBY_NAME[MAX_LOBBY_LENGHT_NAME],
    LOBBY_CREATOR,
    LOBBY_MEMBERS
}

new Array:g_ArrayLobbyData, Array:g_ArrayDefaultLobbiesNames;

enum _:LOBBY_CVARS{
	CVAR_ADMIN,
	CVAR_MAXMEMBERS,
	CVAR_MAXLOBBIES
}

new g_iLobbyCvars[LOBBY_CVARS];

enum _:LOBBY_STATUS{
	LOBBY_STATUS_MEMBER,
	LOBBY_STATUS_OWNER
}

new const szLobbyStatus[][] = {"[Member]", "[Owner]"};

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_dictionary(FILE_LANG);
	
	g_iLobbyCvars[CVAR_ADMIN] = register_cvar("lobby_admin", "0");
	g_iLobbyCvars[CVAR_MAXMEMBERS] = register_cvar("lobby_maxmembers", "8");
	g_iLobbyCvars[CVAR_MAXLOBBIES] = register_cvar("lobby_maxlobby", "32");
	
	register_clcmd("say_team", "HookSayTeam"); register_clcmd("say", "HookSay");
	
	LoadLobbiesFile();
}

public plugin_precache(){
	g_ArrayLobbyData = ArrayCreate(LOBBY_DATA);
	g_ArrayDefaultLobbiesNames = ArrayCreate(MAX_LOBBY_LENGHT_NAME, 1);
}

public plugin_end(){
	ArrayDestroy(g_ArrayLobbyData); ArrayDestroy(g_ArrayDefaultLobbiesNames);
}

public client_disconnected(id){
	ClearPlayerBit(g_iIsConnected, id);

	if(GetPlayerBit(g_iIsOwner, id)) DeleteLobby(id);
	else UpdateLobbyMembers(id);

	g_szInvitation[id][0] = EOS;
}

public client_putinserver(id){
	SetPlayerBit(g_iIsConnected, id);

	g_iLobbySelected[id] = -1;
	g_iOwnerLobbyIndex[id] = -1;

	for(new i; i < MAX_LOBBIES; i++) ClearPlayerBit(g_iPlayerLobby[i], id);
}

CreateLobby(const iId, const szLobbyName[]){
	if(!g_iLobbiesCount){
		CreateInNewSlot(iId, szLobbyName, 0);
		return;
	}

	new iArraySize = ArraySize(g_ArrayLobbyData);
	new iData[LOBBY_DATA];

	for(new i; i < MAX_LOBBIES; i++){
		if(i >= iArraySize){
			CreateInNewSlot(iId, szLobbyName, i);
			break;
		}
		
		ArrayGetArray(g_ArrayLobbyData, i, iData);
		if(iData[LOBBY_CREATOR] == 0){
			UpdateLobby(iId, szLobbyName, i);
			break;
		}
	}
}

CreateInNewSlot(const iId, const szLobbyName[], iSlot){
	g_iOwnerLobbyIndex[iId] = iSlot;
	SetPlayerBit(g_iPlayerLobby[iSlot], iId);
	SetPlayerBit(g_iIsOwner, iId);

	new iData[LOBBY_DATA];
	copy(iData[LOBBY_NAME], charsmax(iData), szLobbyName);
	iData[LOBBY_CREATOR] = iId;
	iData[LOBBY_MEMBERS] = 1;
	ArrayPushArray(g_ArrayLobbyData, iData);

	g_iLobbiesCount++;
	client_print_color(iId, print_team_default, "%L", LANG_PLAYER, "SZ_CREATE", szLobbyName);
}

UpdateLobby(const iId, const szLobbyName[], iSlot){
	g_iOwnerLobbyIndex[iId] = iSlot;
	SetPlayerBit(g_iPlayerLobby[iSlot], iId);
	SetPlayerBit(g_iIsOwner, iId);

	new iData[LOBBY_DATA];
	copy(iData[LOBBY_NAME], charsmax(iData), szLobbyName);
	iData[LOBBY_CREATOR] = iId;
	iData[LOBBY_MEMBERS] = 1;
	ArraySetArray(g_ArrayLobbyData, iSlot, iData);

	g_iLobbiesCount++;
	client_print_color(iId, print_team_default, "%L", LANG_PLAYER, "SZ_CREATE", szLobbyName);
}

DeleteLobby(const iId){
	new iData[LOBBY_DATA]; iData[LOBBY_CREATOR] = 0;
	ArraySetArray(g_ArrayLobbyData, g_iOwnerLobbyIndex[iId], iData);

	for(new iLobbyPlayers = 1; iLobbyPlayers <= MAX_PLAYERS; iLobbyPlayers++){
		if(iLobbyPlayers == iId) continue;

		if(g_iLobbySelected[iLobbyPlayers] == g_iOwnerLobbyIndex[iId]) g_iLobbySelected[iLobbyPlayers] = -1;

		if(GetPlayerBit(g_iPlayerLobby[g_iOwnerLobbyIndex[iId]], iLobbyPlayers)){
			ClearPlayerBit(g_iPlayerLobby[g_iOwnerLobbyIndex[iId]], iLobbyPlayers);
		}
	}

	ClearPlayerBit(g_iPlayerLobby[g_iOwnerLobbyIndex[iId]], iId);
	ClearPlayerBit(g_iIsOwner, iId);

	if(g_iLobbySelected[iId] == g_iOwnerLobbyIndex[iId]) g_iLobbySelected[iId] = -1;

	g_iOwnerLobbyIndex[iId] = -1;
	g_iLobbiesCount--;
}

UpdateLobbyMembers(const iId){
	new iData[LOBBY_DATA];

	for(new i; i < MAX_LOBBIES; i++){
		if(GetPlayerBit(g_iPlayerLobby[i], iId)){
			ArrayGetArray(g_ArrayLobbyData, i, iData);
			iData[LOBBY_MEMBERS]--;
			ArraySetArray(g_ArrayLobbyData, i, iData);
			ClearPlayerBit(g_iPlayerLobby[i], iId);
		}
	}
}

IsPlayerInLobby(const iId){
	new bool:bInLobby;

	for(new i; i < MAX_LOBBIES; i++){
		if(GetPlayerBit(g_iPlayerLobby[i], iId)){
			bInLobby = true;
			break;
		}
	}

	return bInLobby;
}

public HookSay(const iId){
	if(!GetPlayerBit(g_iIsConnected, iId)) return PLUGIN_HANDLED;

	static szSay[192]; read_args(szSay, charsmax(szSay));
	remove_quotes(szSay);
	replace_all(szSay, charsmax(szSay), "%", " ");
	
	if(equali(szSay, "")) return PLUGIN_HANDLED;
	
	if(equal(szSay, szLobbyMenuCommand)){
		ShowLobbyMenu(iId);
		return PLUGIN_HANDLED;
	}
	
	new iCommandLen = strlen(szLobbyCreateCommand);
	if(equal(szSay, szLobbyCreateCommand, iCommandLen)){
		if(strlen(szSay) > MAX_LOBBY_LENGHT_NAME){
			client_print(iId, print_center, "%L", LANG_PLAYER, "SZ_HIGH_NAME");
			return PLUGIN_HANDLED;
		}

		if(get_pcvar_num(g_iLobbyCvars[CVAR_ADMIN]) && !(get_user_flags(iId) & ADMIN_FLAG)){
			client_print(iId, print_center, "%L", LANG_PLAYER, "SZ_ADMINS");
			return PLUGIN_HANDLED;
		}

		if(GetPlayerBit(g_iIsOwner, iId)) client_print(iId, print_center, "%L", LANG_PLAYER, "SZ_CREATOR");
		else if(g_iLobbiesCount >= get_pcvar_num(g_iLobbyCvars[CVAR_MAXLOBBIES])) client_print(iId, print_center, "%L", LANG_PLAYER, "SZ_MAXLOBBYS");
		else if(SanitizeChat(szSay[iCommandLen])) CreateLobby(iId, szSay[iCommandLen]);
		
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

// THX MANU
SanitizeChat( szArgs[ ] )
{
    new iLen = strlen( szArgs );
    
    if ( iLen == 0 )
    {
        return false;
    }
    
    new bool:bSpace = true;
    
    new iCount = 0;
    
    for ( new i = 0; i < iLen ; i++ )
    {        
        if ( szArgs[ i ] == 32 )
        {
            if ( bSpace )
            {
                continue;
            }
            
            bSpace = true;
        }
        else
        {
            bSpace = false;
        }
        
        szArgs[ iCount++ ] = szArgs[ i ];
    }
    
    szArgs[ iCount ] = EOS;
    
    return ( iCount != iLen );
}

public HookSayTeam(const iId){	
	if(g_iLobbySelected[iId] < 0){
		client_print(iId, print_center, "%L", LANG_PLAYER, "SZ_NOT_EXIST");
		ShowLobbyMenu(iId);
		return PLUGIN_HANDLED;
	}
	
	static szSay[192]; read_args(szSay, charsmax(szSay));
	remove_quotes(szSay);
	replace_all(szSay, charsmax(szSay), "%", " ");
	
	if(equali(szSay, "")) return PLUGIN_HANDLED;
	
	static szName[32]; get_user_name(iId, szName, charsmax(szName));
	static iData[LOBBY_DATA]; ArrayGetArray(g_ArrayLobbyData, g_iLobbySelected[iId], iData);

	for(new iLobbyPlayers = 1; iLobbyPlayers <= MAX_PLAYERS; iLobbyPlayers++){
		if(!GetPlayerBit(g_iIsConnected, iLobbyPlayers) || !GetPlayerBit(g_iPlayerLobby[g_iLobbySelected[iId]], iLobbyPlayers)) continue;

		client_print_color(iLobbyPlayers, print_team_default, "^x04[%s]^x03%s ^x03%s^x01: %s", 
		iData[LOBBY_NAME], (g_iLobbySelected[iId] == g_iOwnerLobbyIndex[iId]) ? szLobbyStatus[LOBBY_STATUS_OWNER] : szLobbyStatus[LOBBY_STATUS_MEMBER], szName, szSay);
	}
	
	return PLUGIN_HANDLED;
}

ShowLobbyMenu(const iId){
	new iMenu = menu_create("Lobby Menu", "LobbyMenu");
	
	if(get_pcvar_num(g_iLobbyCvars[CVAR_ADMIN]) && !(get_user_flags(iId) & ADMIN_FLAG))
		menu_additem(iMenu, "\dCreate Lobby", "1");
	else 
		menu_additem(iMenu, "Create Lobby", "1");
	
	menu_additem(iMenu, "Join Lobby", "2");
	menu_additem(iMenu, "Delete Lobby", "3");
	menu_additem(iMenu, "Exit Lobby", "4");
	menu_additem(iMenu, "Select Lobby", "4");
	
	menu_display(iId, iMenu);
	return PLUGIN_HANDLED;
}

public LobbyMenu(iId, iMenu, iItem){
	if(iItem == MENU_EXIT || !GetPlayerBit(g_iIsConnected, iId)){	
		menu_destroy(iMenu);
		return PLUGIN_HANDLED;
	}

	menu_destroy(iMenu);
	
	switch(iItem){
		case 0:{
			if(get_pcvar_num(g_iLobbyCvars[CVAR_ADMIN]) && !(get_user_flags(iId) & ADMIN_FLAG)){
				client_print(iId, print_center, "%L", LANG_PLAYER, "SZ_ADMINS");
				ShowLobbyMenu(iId);
			}
			else ShowMenuCreateLobby(iId);
		}
		case 1: {
			if(!g_iLobbiesCount){
				client_print(iId, print_center, "%L", LANG_PLAYER, "SZ_NOT");
				ShowLobbyMenu(iId);
			}
			else ShowMenuJoinLobby(iId);
		}
		case 2: {
			if(!GetPlayerBit(g_iIsOwner, iId)){
				client_print(iId, print_center, "%L", LANG_PLAYER, "SZ_NOT_LOBBY");
				ShowLobbyMenu(iId);
			}
			else DeleteLobby(iId);
		}
		case 3: {
			if(!IsPlayerInLobby(iId)){
				client_print(iId, print_center, "%L", LANG_PLAYER, "SZ_NOT_LOBBY");
				ShowLobbyMenu(iId);
			}
			else ShowMenuExitLobby(iId);
		}
		case 4:{
			if(!IsPlayerInLobby(iId)){
				client_print(iId, print_center, "%L", LANG_PLAYER, "SZ_NOT_LOBBY");
				ShowLobbyMenu(iId);
			}
			else ShowMenuSelectLobby(iId);
		}
	}
	
	return PLUGIN_HANDLED;
}

ShowMenuCreateLobby(const iId){	
	new iMenu = menu_create("Select Name", "MenuCreateLobby");
	static szBuffer[MAX_LOBBY_LENGHT_NAME];
	
	for(new i; i < ArraySize(g_ArrayDefaultLobbiesNames); i++){
		ArrayGetString(g_ArrayDefaultLobbiesNames, i, szBuffer, charsmax(szBuffer));
		menu_additem(iMenu, szBuffer);
	}

	menu_display(iId, iMenu);
}

public MenuCreateLobby(iId, iMenu, iItem){	
	if(iItem == MENU_EXIT || !GetPlayerBit(g_iIsConnected, iId)){	
		menu_destroy(iMenu);
		return PLUGIN_HANDLED;
	}
	
	menu_destroy(iMenu);

	if(GetPlayerBit(g_iIsOwner, iId)){
		client_print(iId, print_center, "%L", LANG_PLAYER, "SZ_CREATOR");
		ShowMenuCreateLobby(iId);
		return PLUGIN_HANDLED;
	}
	
	if(g_iLobbiesCount >= get_pcvar_num(g_iLobbyCvars[CVAR_MAXLOBBIES])){
		client_print(iId, print_center, "%L", LANG_PLAYER, "SZ_MAXLOBBYS");
		ShowLobbyMenu(iId);
		return PLUGIN_HANDLED;
	}
	
	new szBuffer[MAX_LOBBY_LENGHT_NAME];
	ArrayGetString(g_ArrayDefaultLobbiesNames, iItem, szBuffer, charsmax(szBuffer));
	CreateLobby(iId, szBuffer);
	
	return PLUGIN_HANDLED;
}

ShowMenuExitLobby(const iId){
	new iMenu = menu_create("Exit Lobby", "MenuExitLobby");

	new szPos[4], szPlayerName[32], iData[LOBBY_DATA];
	for(new i; i < ArraySize(g_ArrayLobbyData); i++){
		if(GetPlayerBit(g_iPlayerLobby[i], iId)){
			ArrayGetArray(g_ArrayLobbyData, i, iData);
			get_user_name(iData[LOBBY_CREATOR], szPlayerName, charsmax(szPlayerName));
			num_to_str(i, szPos, charsmax(szPos));
			menu_additem(iMenu, fmt("%s \r(%s)", iData[LOBBY_NAME], szPlayerName), szPos);
		}
	}
	
	menu_display(iId, iMenu);
}

public MenuExitLobby(iId, iMenu, iItem){
	if(iItem == MENU_EXIT || !GetPlayerBit(g_iIsConnected, iId)){	
		menu_destroy(iMenu);
		return PLUGIN_HANDLED;
	}

	new szItemPos[4], iItemPos; menu_item_getinfo(iMenu, iItem, _, szItemPos, charsmax(szItemPos), _, _, _);
	iItemPos = str_to_num(szItemPos);

	menu_destroy(iMenu);
	
	if(!GetPlayerBit(g_iPlayerLobby[iItemPos], iId)){
		client_print(iId, print_center, "%L", LANG_PLAYER, "SZ_NOT_EXIST");
		ShowLobbyMenu(iId);
		return PLUGIN_HANDLED;
	}

	if(g_iOwnerLobbyIndex[iId] == iItemPos)
	{
		ShowLobbyMenu(iId);
		return PLUGIN_HANDLED;
	}
	
	UpdateLobbyMembers(iId);
	return PLUGIN_HANDLED;
}

ShowMenuSelectLobby(const iId){
	new iMenu = menu_create("Select Lobby^n\ySpeak with say team", "MenuSelectLobby");
	
	new szPos[4], szPlayerName[32], iData[LOBBY_DATA];
	for(new i; i < ArraySize(g_ArrayLobbyData); i++){
		if(GetPlayerBit(g_iPlayerLobby[i], iId)){
			ArrayGetArray(g_ArrayLobbyData, i, iData);
			get_user_name(iData[LOBBY_CREATOR], szPlayerName, charsmax(szPlayerName));
			num_to_str(i, szPos, charsmax(szPos));
			menu_additem(iMenu, fmt("%s \r(%s)", iData[LOBBY_NAME], szPlayerName), szPos);
		}
	}
	
	menu_display(iId, iMenu);
}

public MenuSelectLobby(iId, iMenu, iItem){
	if(iItem == MENU_EXIT || !GetPlayerBit(g_iIsConnected, iId)){	
		menu_destroy(iMenu);
		return PLUGIN_HANDLED;
	}

	new szItemPos[4], iItemPos; menu_item_getinfo(iMenu, iItem, _, szItemPos, charsmax(szItemPos), _, _, _);
	iItemPos = str_to_num(szItemPos);

	menu_destroy(iMenu);

	if(!GetPlayerBit(g_iPlayerLobby[iItemPos], iId)){
		client_print(iId, print_center, "%L", LANG_PLAYER, "SZ_NOT_EXIST");
		ShowLobbyMenu(iId);
		return PLUGIN_HANDLED;
	}
	
	g_iLobbySelected[iId] = iItemPos;
	
	return PLUGIN_HANDLED;
}

ShowMenuJoinLobby(const iId){
	new iMenu = menu_create("Join Lobby", "MenuJoinLobby");
	
	new iData[LOBBY_DATA];

	new szPos[4], szPlayerName[32];
	for(new i; i < ArraySize(g_ArrayLobbyData); i++){
		ArrayGetArray(g_ArrayLobbyData, i, iData);

		if(iData[LOBBY_CREATOR] == 0) continue;
		
		get_user_name(iData[LOBBY_CREATOR], szPlayerName, charsmax(szPlayerName));
		num_to_str(i, szPos, charsmax(szPos));
		menu_additem(iMenu, fmt("%s (\r%d/%d\w) \y(%s)", 
		iData[LOBBY_NAME], iData[LOBBY_MEMBERS], get_pcvar_num(g_iLobbyCvars[CVAR_MAXMEMBERS]), szPlayerName), szPos);
	}
	
	menu_display(iId, iMenu);
}

public MenuJoinLobby(iId, iMenu, iItem){	
	if(iItem == MENU_EXIT || !GetPlayerBit(g_iIsConnected, iId)){	
		menu_destroy(iMenu);
		return PLUGIN_HANDLED;
	}

	new szItemPos[4], iItemPos; menu_item_getinfo(iMenu, iItem, _, szItemPos, charsmax(szItemPos), _, _, _);
	iItemPos = str_to_num(szItemPos);

	menu_destroy(iMenu);
	
	if(GetPlayerBit(g_iPlayerLobby[iItemPos], iId)){
		client_print(iId, print_center, "%L", LANG_PLAYER, "SZ_ALREADY");
		ShowMenuJoinLobby(iId);
		return PLUGIN_HANDLED;
	}

	new iData[LOBBY_DATA]; ArrayGetArray(g_ArrayLobbyData, iItemPos, iData);

	if(iData[LOBBY_CREATOR] < 0) return PLUGIN_HANDLED; // LOBBY NOT EXITS!

	if(iData[LOBBY_MEMBERS] >= get_pcvar_num(g_iLobbyCvars[CVAR_MAXMEMBERS])){
		client_print(iId, print_center, "%L", LANG_PLAYER, "SZ_MAXMEMBERS");
		ShowMenuJoinLobby(iId);
		return PLUGIN_HANDLED;
	}
	
	SendInvitation(iId, iData[LOBBY_CREATOR]);
	return PLUGIN_HANDLED;
}

SendInvitation(iId, iOwner){
	get_user_name(iId, g_szInvitation[iOwner], charsmax(g_szInvitation[]));
	ShowMenuAccept(iOwner);
}

ShowMenuAccept(const iId){	
	new iMenu = menu_create(fmt("You recived a invitation from %s", g_szInvitation[iId]), "MenuAccept");
	menu_additem(iMenu, "Accept", "1");
	menu_additem(iMenu, "Decline", "2");
	
	menu_setprop(iMenu, MPROP_EXIT, MEXIT_NEVER);
	menu_display(iId, iMenu);
}

public MenuAccept(iId, iMenu, iItem){
	if(iItem == MENU_EXIT || !GetPlayerBit(g_iIsConnected, iId)){	
		menu_destroy(iMenu);
		return PLUGIN_HANDLED;
	}

	new iMember = get_user_index(g_szInvitation[iId]);
	new szNameOwner[32]; get_user_name(iId, szNameOwner, charsmax(szNameOwner));

	if(iItem){
		client_print(iMember, print_chat, "%L", LANG_PLAYER, "SZ_DECLINE", szNameOwner);
	}
	else{
		new iData[LOBBY_DATA]; ArrayGetArray(g_ArrayLobbyData, g_iOwnerLobbyIndex[iId], iData);
		iData[LOBBY_MEMBERS]++;
		ArraySetArray(g_ArrayLobbyData, g_iOwnerLobbyIndex[iId], iData);
		SetPlayerBit(g_iPlayerLobby[g_iOwnerLobbyIndex[iId]], iMember);
		client_print(iMember, print_chat, "%L", LANG_PLAYER, "SZ_ACCEPT", szNameOwner);
	}
	
	menu_destroy(iMenu);
	return PLUGIN_HANDLED;
}

LoadLobbiesFile()
{
	new szConfigDir[64]; get_configsdir(szConfigDir, charsmax(szConfigDir));
	format(szConfigDir, charsmax(szConfigDir), "%s/%s", szConfigDir, FILE_LOBBY);
	
	if(!file_exists(szConfigDir))
	{
		set_fail_state("[AMXX] Can't Load Config File");
		return;
	}
	
	new szData[MAX_LOBBY_LENGHT_NAME];
	new iFile = fopen(szConfigDir, "rt");
	
	while(iFile && !feof(iFile))
	{
		fgets(iFile, szData, charsmax(szData));
		trim(szData);
		remove_quotes(szData);

		if(szData[0] == ';' || !szData[0]) continue;

		ArrayPushString(g_ArrayDefaultLobbiesNames, szData);
	}
	
	if(iFile) fclose(iFile);
}

/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang3082\\ f0\\ fs16 \n\\ par }
*/
