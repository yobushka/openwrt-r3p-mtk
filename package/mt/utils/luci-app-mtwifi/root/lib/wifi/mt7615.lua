#!/usr/bin/lua

-- Alternative for OpenWrt's /sbin/wifi.
-- Copyright Not Reserved.
-- Hua Shao <nossiac@163.com>
-- - - - - - - - - - - - - - - - - -
--
-- For MT7615+MT7615, MT7603+MT7615 and MT7603+MT7612
-- https://github.com/Azexios/openwrt-r3p-mtk

package.path = '/lib/wifi/?.lua;'..package.path

local function esc(x)
   return (x:gsub('%%', '%%%%')
			:gsub('^%^', '%%^')
			:gsub('%$$', '%%$')
			:gsub('%(', '%%(')
			:gsub('%)', '%%)')
			:gsub('%.', '%%.')
			:gsub('%[', '%%[')
			:gsub('%]', '%%]')
			:gsub('%*', '%%*')
			:gsub('%+', '%%+')
			:gsub('%-', '%%-')
			:gsub('%?', '%%?'))
end

-- local vif_prefix = {"ra", "rai", "rae", "rax", "ray", "raz",
--	"apcli", "apclix", "apclii", "apcliy", "apclie", "apcliz", }

function vif_pre(devname)
	if devname == "mt7615.1" then
		return {"ra", "apcli"}
	elseif devname == "mt7615.2" then
		return {"rai", "apclii"}
	else
		return {"ra", "rai", "apcli", "apclii"}
	end
end

function mt7615_vifup_save(devname)
	local nixio = require("nixio")
	local mtkwifi = require("mtkwifi")
	local vif_prefix = vif_pre(devname)
	nixio.syslog("debug", "mt7615_vifup_save called!")
	
	for _,pre in ipairs(vif_prefix) do
		for _,vif in ipairs(string.split(mtkwifi.read_pipe("ls /sys/class/net"), "\n"))
		do
			if string.match(vif, pre.."[0-9]+") then
				os.execute("ip link ls up | grep -o "..vif.." >> /tmp/mtk/vifup-save")
			end
		end
	end
end

function mt7615_ifup_save(devname)
	local nixio = require("nixio")
	local mtkwifi = require("mtkwifi")
	local vif_prefix = vif_pre(devname)
	nixio.syslog("debug", "mt7615_ifup_save called!")

	for _,pre in ipairs(vif_prefix) do
		for _,vif in ipairs(string.split(mtkwifi.read_pipe("ls /sys/class/net"), "\n"))
		do
			if string.match(vif, pre.."[0-9]+") then
				os.execute("uci show network | grep "..vif.." | sed 's/^.*network.//;s/.device.*$//;/^$/d' >> /tmp/mtk/if-save")
			end
		end
	end
	
	os.execute("> /tmp/mtk/ifup-save")
	for _,ifs in ipairs(string.split(mtkwifi.read_pipe("cat /tmp/mtk/if-save"), "\n")) do
		os.execute("ifstatus "..ifs.." | grep -q '.up.: true,' && echo "..ifs.." >> /tmp/mtk/ifup-save")		
	end
		
end

function mt7615_ifup_up(devname)
	local mtkwifi = require("mtkwifi")
	local nixio = require("nixio")
	nixio.syslog("debug", "mt7615_ifup_up called!")
	
	for _,ifs in ipairs(string.split(mtkwifi.read_pipe("cat /tmp/mtk/ifup-save"), "\n")) do
		nixio.syslog("debug", "mt7615_ifup_up: ifup "..ifs)
		os.execute("ifup "..ifs)
	end
	
	os.execute("rm -rf /tmp/mtk/if-save")
	os.execute("rm -rf /tmp/mtk/ifup-save")
	os.execute("rm -rf /tmp/mtk/vifup-save")
end

function mt7615_ifup_down(devname)
	local mtkwifi = require("mtkwifi")
	local nixio = require("nixio")
	nixio.syslog("debug", "mt7615_ifup_down called!")
	
	for _,ifs in ipairs(string.split(mtkwifi.read_pipe("cat /tmp/mtk/ifup-save"), "\n")) do
		nixio.syslog("debug", "mt7615_ifup_down: ifdown "..ifs)
		os.execute("ifdown "..ifs)
	end
end

function mt7615_up(devname)
	local nixio = require("nixio")
	local mtkwifi = require("mtkwifi")
	
	nixio.syslog("debug", "mt7615_up called!")
	
	if not devname then
		-- we have to bring up root vif first, root vif will create all other vifs.
		mt2 = mtkwifi.read_pipe("cat /tmp/mtk/vifup-save | grep -qE '(ra[0-9])|apcli0' && echo 1 2>/dev/null")
		mt5 = mtkwifi.read_pipe("cat /tmp/mtk/vifup-save | grep -qE '(rai[0-9])|apclii0' && echo 1 2>/dev/null")
		
		if mt2 == "1\n" then
			nixio.syslog("debug", "mt7615_up_r: ifconfig ra0 up")
			os.execute("ifconfig ra0 up")
		end		
		if mt5 == "1\n" then
			nixio.syslog("debug", "mt7615_up_r: ifconfig rai0 up")
			os.execute("ifconfig rai0 up")
		end
	end

	for _,vif in ipairs(string.split(mtkwifi.read_pipe("cat /tmp/mtk/vifup-save"), "\n"))
	do
		nixio.syslog("debug", "mt7615_up: ifconfig "..vif.." up")
		os.execute("ifconfig "..vif.." up")
	end
end

function mt7615_vifup_down(devname)
	local nixio = require("nixio")
	local mtkwifi = require("mtkwifi")
	nixio.syslog("debug", "mt7615_vifup_down called!")

	for _,vif in ipairs(string.split(mtkwifi.read_pipe("cat /tmp/mtk/vifup-save"), "\n"))
	do
		nixio.syslog("debug", "mt7615_vifup_down: ifconfig "..vif.." down")
		os.execute("ifconfig "..vif.." down")
	end
end

function mt7615_down_r()
	local nixio = require("nixio")
	local mtkwifi = require("mtkwifi")
	nixio.syslog("debug", "mt7615_down_r called!")
	
	mt2 = mtkwifi.read_pipe("cat /tmp/mtk/vifup-save | grep -q ra0 && echo 1 2>/dev/null")
	mt5 = mtkwifi.read_pipe("cat /tmp/mtk/vifup-save | grep -q rai0 && echo 1 2>/dev/null")
	
	if mt2 ~= "1\n" then
		nixio.syslog("debug", "mt7615_down_r: ifconfig ra0 down")
		os.execute("ifconfig ra0 down")
	end		
	if mt5 ~= "1\n" then
		nixio.syslog("debug", "mt7615_down_r: ifconfig rai0 down")
		os.execute("ifconfig rai0 down")
	end
end

function mt7615_reload(devname)
	local nixio = require("nixio")
	nixio.syslog("debug", "mt7615_reload called!")
	
	mt7615_vifup_save(devname)
	mt7615_ifup_save(devname)
	mt7615_ifup_down(devname)
	mt7615_vifup_down(devname)
	mt7615_up(devname)
	mt7615_ifup_up(devname)
end

function mt7615_restart(devname)
	local nixio = require("nixio")
	nixio.syslog("debug", "mt7615_restart called!")
	
	mt7615_vifup_save()
	mt7615_ifup_save()
	mt7615_ifup_down(devname)
	mt7615_vifup_down(devname)
	nixio.syslog("debug", "mt7615_restart: rmmod mt_wifi")
	os.execute("rmmod mt_wifi")
	nixio.syslog("debug", "mt7615_restart: modprobe mt_wifi")
	os.execute("modprobe mt_wifi")
	mt7615_up()
	mt7615_down_r()
	mt7615_ifup_up(devname)
end

function mt7615_reset(devname)
	local nixio = require("nixio")
	local mtkwifi = require("mtkwifi")
	nixio.syslog("debug", "mt7615_reset called!")
	if mtkwifi.exists("/rom/etc/wireless/mt7615/") then
		os.execute("rm -rf /etc/wireless/mt7615/")
		os.execute("cp -rf /rom/etc/wireless/mt7615/ /etc/wireless/")
		mt7615_reload(devname)
	else
		nixio.syslog("debug", "mt7615_reset: /rom"..profile.." missing, unable to reset!")
	end
end

function mt7615_status(devname)
	return wifi_common_status()
end

function mt7615_detect(devname)
	local nixio = require("nixio")
	local mtkwifi = require("mtkwifi")
	nixio.syslog("debug", "mt7615_detect called!")

	for _,dev in ipairs(mtkwifi.get_all_devs()) do
		local relname = string.format("%s%d%d",dev.maindev,dev.mainidx,dev.subidx)
		print([[
config wifi-device ]]..relname.."\n"..[[
	option type mt7615
	option vendor ralink
]])
		for _,vif in ipairs(dev.vifs) do
			print([[
config wifi-iface
	option device ]]..relname.."\n"..[[
	option ifname ]]..vif.vifname.."\n"..[[
	option network lan
	option mode ap
	option ssid ]]..vif.__ssid.."\n")
		end
	end
end
