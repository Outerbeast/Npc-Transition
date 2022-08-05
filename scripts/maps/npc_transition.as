/* Npc Transition 
by Outerbeast

Custom entities that allow npcs to cross level changes in Sven Co-op

For install and usage instructions, check npc_transition.fgd

Planned features:
- Add a classname/targetname filter
- Add a feature for blacklist inversion
*/
namespace NPC_TRANSITION
{

enum transition_entity_flags
{
    SF_START_OFF            = 1 << 0,
    SF_MINCOUNT_TRIGGER     = 1 << 1,
    SF_INCLUDE_ENEMIES      = 1 << 2,
    SF_IGNORE_BLACKLIST     = 1 << 3
}

enum transition_types
{
    DONT_TRANSITION = -1,
    UNDEFINED,
    DIRECT,
    LANDMARK
}

bool EntityRegister(bool blDeletePrevSaveSetting = true)
{
    g_CustomEntityFuncs.RegisterCustomEntity( "NPC_TRANSITION::CTransitionEntity", "env_transition" );
    g_CustomEntityFuncs.RegisterCustomEntity( "NPC_TRANSITION::CTransitionEntity ", "func_transition" ); // trigger_transition classname is reserved by the game :[
    g_CustomEntityFuncs.RegisterCustomEntity( "NPC_TRANSITION::CLandmarkEntity", "info_landmark" );

    CBaseTransition obj_TransitionFuncs;
    obj_TransitionFuncs.LoadNpcs( g_Engine.mapname, blDeletePrevSaveSetting );
    
    return( g_CustomEntityFuncs.IsCustomEntity( "env_transition" ) || g_CustomEntityFuncs.IsCustomEntity( "func_transition" ) );
}
// Clear all the npc data for a given map list
void PurgeAllNpcs(string strMapList)
{
    if( strMapList == "" )
        return;

    const array<string> STR_MAPLIST = strMapList.Split( ";" );

    if( g_Engine.mapname == STR_MAPLIST[0] )
    {
        CBaseTransition obj_TransitionFuncs;

        for( uint i = 0; i < STR_MAPLIST.length(); i++ )
            obj_TransitionFuncs.ClearSavedNpcs( STR_MAPLIST[i] );
    }
}

class CBaseTransition : ScriptBaseEntity
{
    Vector vecGroundOffset = Vector( 0, 0, 16 );
    string strNpcSaveDir = "store/npcs/";
    // Filter out any monsters not valid for transitioning
    bool MonsterIsValid(EHandle hMonster)
    {
        if( !hMonster )
            return false;
            
        CBaseMonster@ pMonster = cast<CBaseMonster@>( hMonster.GetEntity() );
         
        if( pMonster is null ||
            pMonster.IsPlayer() ||
            !pMonster.IsMonster() || 
            !pMonster.IsInWorld() ||
            ( !pMonster.IsAlive() && !pMonster.IsRevivable() ) )
            return false;

        return true;
    }
    // Hardcoded blacklist for entities not allowed for transitioning
    bool MonsterInBlacklist(string strMonsterClassname, string strCustomBlacklist = "", bool blWhitelist = false)
    {
        if( strMonsterClassname == "" )
            return false;
        // Default blacklisted NPCS
        array<string> STR_NPC_BLACKLIST =
        { 
            "monster_gman",
            "monster_furniture",
            "monster_handgrenade",
            "monster_satchel",
            "monster_tripmine",
            "monster_sentry",
            "monster_turret",
            "monster_miniturret",
            "monster_barnacle",
            "monster_sqknest",
            "monster_snark",
            "monster_assassin_repel",
            "monster_grunt_repel",
            "monster_hwgrunt_repel",
            "monster_torch_ally_repel",
            "monster_medic_ally_repel",
            "monster_hwgrunt_repel",
            "monster_robogrunt_repel",
            "monster_leech",
            "monster_ichthyosaur",
            "monster_gargantua",
            "monster_bigmomma",
            "monster_tentacle",
            "monster_apache",
            "monster_blkop_apache",
            "monster_osprey",
            "monster_blkop_osprey",
            "monstermaker", // Yeah, this actually does derive from CBaseMonster
            "squadmaker"    // ^
        };

        if( strCustomBlacklist != "" )
            STR_NPC_BLACKLIST.insertAt( STR_NPC_BLACKLIST.length() - 1, strCustomBlacklist.Split( ";" ) );
        // Whitelisting is WIP
        return( !blWhitelist ? STR_NPC_BLACKLIST.find( strMonsterClassname ) >= 0 : STR_NPC_BLACKLIST.find( strMonsterClassname ) < 0 );
    }
    //!-HACK-!: "IsPlayerAlly()" doesn't return the true "is_player_ally" value set in the bsp.
    int PlayerRelationToggled(EHandle hMonster)
    {
        if( !hMonster )
            return 0;

        CBaseMonster@ pMonster = cast<CBaseMonster@>( hMonster.GetEntity() );
        CustomKeyvalues@ kvMonster = pMonster.GetCustomKeyvalues();

        if( pMonster is null || !kvMonster.HasKeyvalue( "$i_is_player_ally" ) )
            return 0;

        return( kvMonster.GetKeyvalue( "$i_is_player_ally" ).GetInteger() );
    }

    int GetTransitionType(EHandle hMonster)
    {
        if( !hMonster )
            return UNDEFINED;

        CBaseMonster@ pMonster = cast<CBaseMonster@>( hMonster.GetEntity() );
        CustomKeyvalues@ kvMonster = pMonster.GetCustomKeyvalues();

        if( pMonster is null || !kvMonster.HasKeyvalue( "$i_transition_type" ) )
            return UNDEFINED;

        return( kvMonster.GetKeyvalue( "$i_transition_type" ).GetInteger() );
    }
    // This method is WIP
    bool ClassnameFiltered(string strMonsterClassname, string strClassnameFilter, bool blInvertFilter = false)
    {
        return( !blInvertFilter ? 
                strClassnameFilter.Find( strMonsterClassname ) != String::INVALID_INDEX : 
                strClassnameFilter.Find( strMonsterClassname ) == String::INVALID_INDEX );
    }
    // This method is WIP
    bool TargetnameFiltered(string strMonsterTargetname, string strTargetnameFilter, bool blInvertFilter = false)
    {
        return( !blInvertFilter ? 
                strTargetnameFilter.Find( strMonsterTargetname ) != String::INVALID_INDEX : 
                strTargetnameFilter.Find( strMonsterTargetname ) == String::INVALID_INDEX );
    }

    bool EntityIsStuck(EHandle hEntity)
    {
        if( !hEntity )
            return false;

        CBaseEntity@ pStuckEntity = hEntity.GetEntity();

        return( g_EngineFuncs.WalkMove( pStuckEntity.edict(), pStuckEntity.pev.angles.y, 1.0f, WALKMOVE_NORMAL ) == 0 );
    }

    bool CheckBBoxValid(Vector vecAbsMin, Vector vecAbsMax)
    {
        if( vecAbsMin != g_vecZero && vecAbsMax != g_vecZero && vecAbsMin != vecAbsMax )
        {
            bool blXisValid = vecAbsMax.x > vecAbsMin.x;
            bool blYisValid = vecAbsMax.y > vecAbsMin.y;
            bool blZisValid = vecAbsMax.z > vecAbsMin.z;

            if( !blXisValid )
                g_EngineFuncs.ServerPrint( "Warning: backwards x components '" + vecAbsMin.x + "/" + vecAbsMax.x + "' for min/max points '" + vecAbsMin.ToString() + "/" + vecAbsMax.ToString() + "'! \n" );

            if( !blYisValid )
                g_EngineFuncs.ServerPrint( "Warning: backwards y components '" + vecAbsMin.y + "/" + vecAbsMax.y + "' for min/max points '" + vecAbsMin.ToString() + "/" + vecAbsMax.ToString() + "'! \n" );

            if( !blZisValid )
                g_EngineFuncs.ServerPrint( "Warning: backwards z components '" + vecAbsMin.z + "/" + vecAbsMax.z + "' for min/max points '" + vecAbsMin.ToString() + "/" + vecAbsMax.ToString() + "'! \n" );

            return( blXisValid && blYisValid && blZisValid );
        }
        else
            return false;
    }

    string FormatEntityData(dictionary dictEntityData, string strEntityLabel = "Entity")
    {
        if( dictEntityData.isEmpty() )
            return "";

        string strEntLoaderKeyvalues;
        const string strLineStart = "\"" + strEntityLabel + "\" ";
        const string strEntStart = "{ ", strEntEnd = "}";
        const array<string> STR_KEYS = dictEntityData.getKeys();

        for( uint i = 0; i < STR_KEYS.length(); i++ )
        {
            if( STR_KEYS[i] == "" )
                continue;

            const string strKey = "\"" + STR_KEYS[i] + "\"";
            const string strValue = "\"" + string( dictEntityData[STR_KEYS[i]] ) + "\"";
            const string strKeyValue = strKey + " " + strValue + " ";
            strEntLoaderKeyvalues = strEntLoaderKeyvalues + strKeyValue;
        }

        return( strLineStart + strEntStart + strEntLoaderKeyvalues + strEntEnd );
    }
    
    string GetPrevMap(string strCurrentMap = string( g_Engine.mapname ))
    {
        const string strNpcFile = strNpcSaveDir + strCurrentMap + ".npc";
        File@ fileSavedNpcs = g_FileSystem.OpenFile( "scripts/maps/" + strNpcFile, OpenFile::READ );

        if( fileSavedNpcs is null || !fileSavedNpcs.IsOpen() )
            return "";

        string strCurrentLine, strPrevMap;
        fileSavedNpcs.ReadLine( strCurrentLine );
        strPrevMap = strCurrentLine.Split( "{" )[0].Replace( "\"", "" ).Replace( " ", "" );
        
        return strPrevMap;
    }

    bool LoadNpcs(string strLoadMap = string( g_Engine.mapname ), bool blDeletePrevSave = true)
    {
        const string strNpcFile = strNpcSaveDir + strLoadMap + ".npc";
        
        if( g_FileSystem.OpenFile( "scripts/maps/" + strNpcFile, OpenFile::READ ) is null )
            return false;

        if( blDeletePrevSave && GetPrevMap() != strLoadMap )
            ClearSavedNpcs( GetPrevMap() );

        return g_EntityLoader.LoadFromFile( strNpcFile );
    }

    void ClearSavedNpcs(string strMapName = string( g_Engine.mapname ))
    {
        string strFileName = "scripts/maps/" + strNpcSaveDir + strMapName + ".npc";
        File@ fileNpc = g_FileSystem.OpenFile( strFileName, OpenFile::WRITE );

        if( fileNpc !is null )
            fileNpc.Remove();
    }
}

final class CTransitionEntity : CBaseTransition
{
    private string strNextMap, strCustomBlacklist;
    private Vector vecZoneCornerMin, vecZoneCornerMax, vecLandmark;
    private float flZoneRadius = 256;
    private uint iMinRequired, iMaxEntities;
    private bool blInitialised, blShouldTransition;

    bool KeyValue(const string& in szKey, const string& in szValue)
    {
        if( szKey == "nextmap" )
            strNextMap = szValue;
        else if( szKey == "zonecornermin" )
            g_Utility.StringToVector( vecZoneCornerMin, szValue );
        else if( szKey == "zonecornermax" )
            g_Utility.StringToVector( vecZoneCornerMax, szValue );
        else if( szKey == "zoneradius" )
            flZoneRadius = Math.clamp( 16.0f, 2048.0f, atof( szValue ) );
        else if( szKey == "landmark" )
            g_Utility.StringToVector( vecLandmark, szValue );
        else if( szKey == "mincount" )
            iMinRequired = atoui( szValue ) < 1 ? 1 : atoui( szValue );
        else if( szKey == "maxcount" )
            iMaxEntities = atoui( szValue );
        else if( szKey == "blacklist" )
            strCustomBlacklist = szValue;
        else
            return BaseClass.KeyValue( szKey, szValue );

        return true;
    }

    void Spawn()
    {
        // If the entity has a brush model, treat it like a brush entity
        if( self.GetClassname() == "func_transition" && string( self.pev.model )[0] == "*" )
        {
            g_EntityFuncs.SetModel( self, self.pev.model );
            g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );
            vecZoneCornerMin = self.pev.absmin;
            vecZoneCornerMax = self.pev.absmax;
            flZoneRadius = 0.0f;
        }

        g_EntityFuncs.SetOrigin( self, self.pev.origin );

        self.pev.solid      = SOLID_NOT;
        self.pev.effects    |= EF_NODRAW;

        if( g_Engine.mapname != strNextMap )
            ClearSavedNpcs( strNextMap );

        blInitialised = self.pev.SpawnFlagBitSet( SF_START_OFF) && self.GetTargetname() != "" ? false : Initialise();

        BaseClass.Spawn();
    }
    
    bool Initialise()
    {
        if( blInitialised )
            return true;

        self.pev.nextthink = g_Engine.time + 0.1f;

        if( self.GetTargetname() != "" && self.pev.target != self.GetTargetname() )
            return true;
            
        if( self.pev.SpawnFlagBitSet( SF_MINCOUNT_TRIGGER ) )
            return true;

        iMinRequired = 1;

        return( g_Hooks.RegisterHook( Hooks::Game::MapChange, MapChangeHook( this.Transition ) ) );
    }

    dictionary NpcData(EHandle hMonster)
    {
        if( !hMonster )
            return dictionary();

        CBaseMonster@ pMonster = cast<CBaseMonster@>( hMonster.GetEntity() );

        if( pMonster is null )
            return dictionary();
        
        dictionary dictMonster =
        {
            { "classname",          pMonster.GetClassname() },
            { "origin",             ( pMonster.GetOrigin() + vecLandmark - self.GetOrigin() + vecGroundOffset ).ToString().Replace( ",", "" ) },
            { "angles",             pMonster.pev.angles.ToString().Replace( ",", "" ) },
            { "displayname",        "" + pMonster.m_FormattedName },
            { "health",             "" + pMonster.pev.health },
            { "max_health",         "" + pMonster.pev.max_health },
            { "frags",              "" + pMonster.pev.frags },
            { "body",               "" + pMonster.pev.body },
            { "skin",               "" + pMonster.pev.skin },
            /* { "head",               "0" }, !-LIMITATION-!: "head" is not exposed to the API in any way.*/
            { "weapons",            "" + pMonster.pev.weapons },
            { "bloodcolor",         "" + pMonster.m_bloodColor },
            { "is_not_revivable",   "0" },
            { "TriggerCondition",   "" + pMonster.m_iTriggerCondition },
            { "rendermode",         "" + pMonster.pev.rendermode },
            { "renderamt",          "" + pMonster.pev.renderamt },
            { "renderfx",           "" + pMonster.pev.renderfx },
            { "rendercolor",        pMonster.pev.rendercolor.ToString().Replace( ",", "" ) }
        };

        if( pMonster.GetTargetname() != "" )
            dictMonster["targetname"] = pMonster.GetTargetname();

        if( pMonster.pev.target != "" )
            dictMonster["target"] = "" + pMonster.pev.target;

        if( pMonster.pev.netname != "" )
            dictMonster["netname"] = "" + pMonster.pev.netname;

        if( pMonster.m_fCustomModel )
            dictMonster["model"] = "" + pMonster.pev.model;

        if( pMonster.m_iszTriggerTarget != "" )
            dictMonster["TriggerTarget"] = "" + pMonster.m_iszTriggerTarget;

        if( pMonster.m_iszGuardEntName != "" )
            dictMonster["guard_ent"] = "" + pMonster.m_iszGuardEntName;

        if( pMonster.m_fOverrideClass )
            dictMonster["classify"] = "" + pMonster.m_iClassSelection;

        if( PlayerRelationToggled( pMonster ) > 0 )
            dictMonster["is_player_ally"] = dictMonster["$i_is_player_ally"] = "1";

        if( pMonster.pev.spawnflags > 0 )
            dictMonster["spawnflags"] = "" + ( pMonster.pev.spawnflags & ~( 16 | 64 | 128 | 256 ) );

        dictMonster["$i_transition_type"] = vecLandmark != g_vecZero ? "" + DIRECT : "" + LANDMARK;

        return dictMonster;
    }

    array<dictionary>@ GetNpcs()
    {
        array<CBaseEntity@> P_ENTITIES( iMaxEntities < 1 ? g_EngineFuncs.NumberOfEntities() : iMaxEntities );

        int iNumMonsters =  CheckBBoxValid( vecZoneCornerMin, vecZoneCornerMax ) ?
                            g_EntityFuncs.EntitiesInBox( @P_ENTITIES, vecZoneCornerMin, vecZoneCornerMax, FL_MONSTER ) :
                            g_EntityFuncs.MonstersInSphere( @P_ENTITIES, self.GetOrigin(), flZoneRadius );

        if( iNumMonsters < 1 )
            return array<dictionary>();

        array<dictionary> DICT_MONSTERS;

        for( uint i = 0; i < P_ENTITIES.length(); i++ )
        {
            if( !MonsterIsValid( P_ENTITIES[i] ) || GetTransitionType( P_ENTITIES[i] ) == DONT_TRANSITION )
                continue;

            if( MonsterInBlacklist( P_ENTITIES[i].GetClassname(), strCustomBlacklist ) && !self.pev.SpawnFlagBitSet( SF_IGNORE_BLACKLIST ) )
                continue;

            if( !P_ENTITIES[i].IsPlayerAlly() && !self.pev.SpawnFlagBitSet( SF_INCLUDE_ENEMIES ) )
                continue;

            DICT_MONSTERS.insertLast( NpcData( P_ENTITIES[i] ) );
        }

        return @DICT_MONSTERS;
    }

    void SaveNpcs()
    {
        const array<dictionary> DICT_SAVED_NPCS = GetNpcs();

        if( DICT_SAVED_NPCS.length() < 1 )
            return;

        const string strFileName = "scripts/maps/" + strNpcSaveDir + strNextMap + ".npc";
        File@ fileNpc = g_FileSystem.OpenFile( strFileName, OpenFile::WRITE );

        if( fileNpc !is null && fileNpc.IsOpen() )
        {
            for( uint i = 0; i < DICT_SAVED_NPCS.length(); i++ )
            {
                if( DICT_SAVED_NPCS[i].isEmpty() )
                    continue;

                string strCurrentLine = FormatEntityData( DICT_SAVED_NPCS[i], string( g_Engine.mapname ) );
                fileNpc.Write( "" + strCurrentLine + "\n" );
            }

            if( self.pev.message != "" )
            {
                const dictionary dictAuto =
                {
                    { "classname", "trigger_auto" },
                    { "target", "" + self.pev.message },
                    { "delay", "1" },
                    { "triggerstate", "1" },
                    { "spawnflags", "1" }
                };

                fileNpc.Write( "" + FormatEntityData( dictAuto, "auto" ) + "\n" );
            }

            fileNpc.Close();
        }
    }
    
    void Think()
    {   // Make sure to only save when the number of monsters in the zone matches or exceeds the minimum required
        const uint iNpcsInZone = CheckBBoxValid( vecZoneCornerMin, vecZoneCornerMax ) ?
                                g_EntityFuncs.EntitiesInBox( array<CBaseEntity@>( iMinRequired ), vecZoneCornerMin, vecZoneCornerMax, FL_MONSTER ) :
                                g_EntityFuncs.MonstersInSphere( array<CBaseEntity@>( iMinRequired ), self.GetOrigin(), flZoneRadius ); // !-LIMITATION-!: MonstersInSphere counts player instances. This results in undefined behaviour. Need a flagmask for this method!

        blShouldTransition = iNpcsInZone >= iMinRequired;
        self.pev.frags = float( iNpcsInZone );

        if( blShouldTransition && self.pev.SpawnFlagBitSet( SF_MINCOUNT_TRIGGER ) && self.pev.target != "" && self.pev.target != self.GetTargetname() )
        {
            self.Use( self, self, USE_ON, 0.0f );
            self.pev.nextthink = 0.0f;

            return;
        }

        self.pev.nextthink = g_Engine.time + 0.1f;
    }

    void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
    {
        if( strNextMap == "" || !g_EngineFuncs.IsMapValid( strNextMap ) )
            return;

        if( !blInitialised )
        {
            if( self.pev.SpawnFlagBitSet( SF_START_OFF) )
                self.pev.spawnflags &= ~SF_START_OFF;

            blInitialised = Initialise();

            return;
        }

        if( !blShouldTransition )
        {
            g_EntityFuncs.FireTargets( "" + self.pev.netname, pActivator, pCaller, useType, 0.0f, 0.0f );
            return;
        }

        SaveNpcs();

        self.SUB_UseTargets( pActivator, useType, 0.0f );
    }
    // !-BUG-!: Hook is called twice, during changelevel and again sometime afterwards
    private HookReturnCode Transition()// <- Note to devs: there needs to be more information passed in about the map being changed to and what type of mapchange it is!
    {
        self.Use( self, self, USE_ON, 0.0f );
        self.pev.nextthink = 0.0f;
        blShouldTransition = false;
        
        return HOOK_CONTINUE;
    }
}

final class CLandmarkEntity : CBaseTransition
{
    private int iNumPositioned
    {
        get { return int( self.pev.frags ); }
        set { self.pev.frags = value; }
    }

    void Spawn()
    {
        self.pev.solid      = SOLID_NOT;
        self.pev.movetype   = MOVETYPE_NONE;
        self.pev.effects    |= EF_NODRAW;
        g_EntityFuncs.SetOrigin( self, self.pev.origin );

        if( self.GetTargetname() == "" )
            g_Scheduler.SetTimeout( this, "PositionTransitionNpcs", 0.5f );
        
        BaseClass.Spawn();
    }

    void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
    {
        if( iNumPositioned > 0 ) // The entity has already done its job
            return;

        PositionTransitionNpcs();
    }

    void PositionTransitionNpcs()
    {
        iNumPositioned = 0; // Want to make sure that the count is always 0 at the start
        array<CBaseEntity@> P_ENTITIES( g_EngineFuncs.NumberOfEntities() );
        int iNumMonsters = g_EntityFuncs.Instance( 0 ).FindMonstersInWorld( @P_ENTITIES, FL_MONSTER );

        if( iNumMonsters < 1 )
        {
            iNumPositioned = -1;
            g_EntityFuncs.FireTargets( "" + self.pev.netname, self, self, USE_ON, 0.0f, 0.0f );

            return;
        }

        for( uint i = 0; i < P_ENTITIES.length(); i++ )
        {
            if( !MonsterIsValid( P_ENTITIES[i] ) || GetTransitionType( P_ENTITIES[i] ) < LANDMARK )
                continue;

            g_EntityFuncs.SetOrigin( P_ENTITIES[i], P_ENTITIES[i].GetOrigin() + self.GetOrigin() );

            if( self.pev.angles != g_vecZero )
                P_ENTITIES[i].pev.angles = self.pev.angles;

            if( EntityIsStuck( P_ENTITIES[i] ) )
            {
                float flRandPosX = Math.RandomFloat( 0, 16 );
                float flRandPosY = Math.RandomFloat( 0, 16 );

                g_EntityFuncs.SetOrigin( P_ENTITIES[i], self.GetOrigin() + vecGroundOffset + Vector( flRandPosX, flRandPosY, 0 ) );
            }

            g_EntityFuncs.DispatchKeyValue( P_ENTITIES[i].edict(), "$i_transition_type", "" + UNDEFINED );

            if( self.pev.target != "" )
                self.SUB_UseTargets( P_ENTITIES[i], USE_ON, 0.0f );

            iNumPositioned += 1; // Can't use increment operators on virtual properties. Why????

            if( self.pev.health > 0 && iNumPositioned >= self.pev.health )
                break;
        }

        if( iNumPositioned > 0 )
            g_EntityFuncs.FireTargets( "" + self.pev.message, self, self, USE_ON, 0.0f, 0.0f );
        else
            g_EntityFuncs.FireTargets( "" + self.pev.netname, self, self, USE_ON, 0.0f, 0.0f );

        g_EntityFuncs.Remove( self );
    }
}

}
