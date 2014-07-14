#!/usr/bin/env luvit
-- Copyright vifino
args = process.argv
http = require("http")
fs = require("fs")
os = require("os")
math = require("math")
string = require("string")
table = require("table")
io = require("io")
net = require("net")
_print = print
for k,v in pairs(args) do
	if v == "-p" then
		if not args[k+1] then _print("Please specify the port") process.exit(1) else
			port = args[k+1]
		end
	elseif v == "-r" then
		if not args[k+1] then _print("Please specify the root of the server.") process.exit(1) else
			port = args[k+1]
		end
	end
end

local port = port or 8080
local root = root or "./"
root = root:gsub("/$","")

local contentTypes = {
	-- Text
	html="text/html",
	txt="text/plain",
	c="text/plain",
	cc="text/plain",
	h="text/plain",
	talk="text/x-speech",
	css="text/css",
	-- Image
	gif="image/gif",
	png="image/png",
	jpeg="image/jpeg",
	jpg="image/jpeg",
	jpe="image/jpeg",
	tiff="image/tiff",
	rgb="image/rgb",
	-- Audio
	wav="audio/x-wav",
	-- Application Types
	pdf="application/pdf",
	-- Scripts
	js="text/javascript",
	ls="text/javascript",
	mocha="text/javascript",
	sh="application/x-sh",
	csh="application/x-csh",
	pl="application/x-perl"
}

function getFileext(filename)
	return filename:match("[^$.]+$") or filename or ""
end

function file_exists(name)
	local f=io.open(name,"r")
	if f~=nil then
		io.close(f)
		return true
	else
		return false
	end
end

function getContentType(filename)
	local ext = getFileext(filename)
	ext = ext:lower()
	return contentTypes[ext] or "text/plain"
end

function execLuaFile(content,filename,req,res,args)
	content = content.."\n"
	if content then
		--local success,func = pcall(loadstring(content))
		--local header = "os=require(\"os\") table=require(\"table\") string=require(\"string\") local __OUTPUT = \"\" print=function(...) local t={...} __OUTPUT=__OUTPUT..(table.concat(t,\"\\t\") or \"\")..\"\\n\" end \n"
		local headerRequire = "os=require(\"os\") table=require(\"table\") string=require(\"string\")\n"
		--local headerVars = "local req=({...})[1] local args=({...})[2] local filename=({...})[3] \n"
		local headerVars = "__ARGS={...} req=__ARGS[1] res=__ARGS[2] args=__ARGS[3] filename=__ARGS[4] __HEADER = {} \n"
		local headerPrint = "local __OUTPUT = \"\" print=function(...) local t={...} for k,v in pairs(t) do if not k~=1 then tab=\"\\t\" else tab=\"\" end __OUTPUT=__OUTPUT..tostring(v)..tab end __OUTPUT=__OUTPUT..\"\\n\" end \n"
		local headerGet = "function get(key) return args[key] end \n"
		local headerJS = "function js(code) print(\"<script type=\\\"text/javascript\\\"> \"..(code or \";\")..\" </script>\") end \n"
		local headerScriptJS = "function loadJS(loc) print(\"<script type=\\\"text/javascript\\\" src=\"..loc..\"> </script>\") end \n"
		local headerRedirect = "function redirect(url) js(\"window.location = \"..url..\";\") return nil,303 end \n" -- Not working i think
		local headerAlert = "function alert(text) js('alert(\"'..(text or \"\")..'\");') end\n"
		local headerScriptJS = [[function loadJS(loc) print('<script type="text/javascript" src="'..loc..'"> </script>') end]].."\n"
		--local headerHeader = "function setHeader(k,v) __HEADER[k] = v return true end"
		local hasReturn = string.match(content,"return")
		if hasReturn then
			local content = content:gsub("return","return __OUTPUT,__HEADER,") or content
		else
			content = content.."\n return __OUTPUT,__HEADER"
		end
		header = headerRequire..headerVars..headerPrint..headerJS..headerGet..headerRedirect..headerScriptJS..headerAlert
		_print(header..content)
		local success,body1,newHeader,body2,respcode,mimetype = pcall(loadstring(header..content),req,res,args,filename)
		if success then
			--local success2,body,respcode,mimetype = pcall(func,req,filename)
			--print(success2,body,respcode,mimetype)
			--if success2 then
			return (respcode or 200),(tostring(body1 or "")..tostring(body2 or "")),(mimetype or "text/html"),(newHeader or {})
			--else
			--	return 500,"Lua Error: "..tostring(body),"text/plain"
			--end
		else
			return 500,"Lua Error: "..tostring(body1),"text/plain"
		end
	else
		return 500,"No content","text/plain"
	end
end

function getBody(filename,req,res,args)
	local success,h = pcall(io.open,filename,"r")
	local content = h:read("*all") or ""
	h:close()
	if success then
		local fileext = getFileext(filename)
		local contentType = getContentType(filename)
		if fileext=="lua" then
			local respcode, cont, mimetype,newHeader = execLuaFile((content or ""),(filename or ""),(req or {}),(res or {}),(args or {}))
			print(cont)
			return respcode, cont, mimetype,newHeader
		else
			return 200, tostring(content), contentType
		end
	else
		_print("No such file")
		return 404,nil,"text/plain"
	end
end

http.createServer(function(req, res)
	local resp = 404
	local content = ""
	local mimetype = "text/plain"
	--redirection = nil
	local newHeaders={["Content-Type"]="text/plain"}
	local url,argsRaw = req.url:match("(.-)?(.*)")
	argsRaw = (argsRaw or "").."&"
	argsRaw = argsRaw:gsub("%%20"," ") or argsRaw
	args ={}
	string.gsub(argsRaw,"(.-)&",function(str)
		local key,cont = str:match("^(.-)=(.*)")
		if key and cont then
			args[key] = cont
		end
	end)
	req.url = url or req.url
	print(args)
	print("Got Request for "..req["url"])
	local file = root..req.url
	if string.match(req["url"],"/$") then
		if file_exists(file.."index.lua") then
			resp,content,mimetype,newHeader = getBody(file.."index.lua",req,res,args)
			newHeaders = newHeader or newHeaders
		elseif file_exists(file.."index.html") then
			resp,content,mimetype,newHeader = getBody(file.."index.html",req,res,args)
			newHeaders = newHeader or newHeaders
		else
			resp = 404
			content = "No such file or Directory"
			mimetype = "text/plain"
		end
	else
		if file_exists(file) then
			resp,content,mimetype,newHeader = getBody(file,req,res,args)
			newHeaders = newHeader or newHeaders
		else
			resp = 404
			content = "No such file or Directory"
			mimetype = "text/plain"
		end
	end
	res:on("error", function(err)
		msg = tostring(err)
		_print("Error while sending a response: " .. msg)
	end)
	--if resp ~= 404 then
	local finalHeader = {
		["Content-Type"] = mimetype,
		["Content-Length"] = #content
	}
	--if redirection then _print("Redirection!") finalHeader["Location"] = redirection end
	if newHeader then
		for k,v in pairs(newHeaders) do
			if v then
				finalHeader[k] = v
			end
		end
	end
	if resp~=404 then
		res:writeHead(resp, finalHeader)
		res:finish(content)
	else
		res:writeHead(404, {["Content-Type"]="text/html"})
		--req.socket:write("HTTP/1.0 404 Not Found\r\n")
		res:finish()--"Not Found")
	end
	--[[else
		res:writeHead(404, {
			["Content-Type"] = "text/plain"
		})
		--res:code(404)
		res:finish("404 Not Found")--content)]]
	--end
end):listen(port)
_print("Server listening at http://localhost:"..tostring(port).."/")
