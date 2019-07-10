
ulx_leysql.BanMessage = "[BANNED]\r\n\r\n-=Banned By=-\r\n%s\r\n\r\n-=Reason=-\r\n%s\r\n\r\n-= Time Left =-\r\n%s"
ulx_leysql.BanMessage_PermaTime = "You have to wait for all eternity"

if(ulx_leysql.GetDBData) then return end

local ip_n_port = game.GetIPAddress()
local ip_n_port_divider = string.find(ip_n_port, ":")

ulx_leysql.sqldb.gmodserver = {}
ulx_leysql.sqldb.gmodserver.ip = string.sub(ip_n_port, 0, ip_n_port_divider-1) -- returns ip like ulx_leysql.sqldb.gmodserver.ip = "1.1.1.1"
ulx_leysql.sqldb.gmodserver.port = tonumber(string.sub(ip_n_port, ip_n_port_divider+1)) -- returns port like ulx_leysql.sqldb.gmodserver.port = 1337


local doneonce = false
function ulx_leysql.GetDBData()
	if(false&&doneonce) then
		return
	else
		doneonce = true
		ulx_leysql.sqldb.Hostname = "127.0.0.1"-- the IP
		ulx_leysql.sqldb.Database = "test" -- the Database name
		ulx_leysql.sqldb.Username = "test" -- the Username
		ulx_leysql.sqldb.Password = "test" -- the mysql password
		ulx_leysql.sqldb.Port = 3306 -- the mysql port
	end
end
