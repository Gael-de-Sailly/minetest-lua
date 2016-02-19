lua = {}
me = nil
here = nil

local old_print = print

local function get_formspec(player)
	return "size[8,10]image[0.5,0.5;1,1;lua.png]label[2,0.5;In-game Lua console: type your code here and press \"Execute\".]textarea[0.5,2;7,2.5;input;Input box;"
		.. minetest.formspec_escape(lua.input_history[player] or "")
		.. "]textarea[0.5,5;7,3.5;output;Output box;"
		.. minetest.formspec_escape(lua.output_history[player] or "")
		.. "]button[1.75,8;2,1.5;execute;Execute]button_exit[4.25,8;2,1.5;quit;Quit]"
end

function lua.show(name)
	local formspec = get_formspec(name)
	minetest.after(1, function() minetest.show_formspec(name, "lua:lua", formspec) end)
	return true, "Write your code ..."
end

lua.input_history = {}
lua.output_history = {}

minetest.register_chatcommand("lua", {
	description = "Run a Lua console, or run directly a short command",
	privs = {server = true},
	params = "<command>",
	func = function(name, params)
		if #params == 0 then
			lua.show(name)
			return true, "Write your code ..."
		else
			local success, outputbox = lua.run(params, minetest.get_player_by_name(name))
			local history = lua.output_history[name] or ""

			if history:len() == 0 then
				lua.output_history[name] = outputbox
			else
				lua.output_history[name] = history .. "\n" .. outputbox
			end
		end
		return true
	end,
})

function lua.run(command, player)
	local success
	local printed = {}

	me = player
	here = me:getpos()

	local name = player:get_player_name()

	function print(...)
		for _, v in ipairs({...}) do
			local str = tostring(v)
			for line in str:gmatch("[^\n]+") do
				minetest.chat_send_player(name, line)
				table.insert(printed, line)
				minetest.log("action", line)
			end
		end
	end

	minetest.log("action", name .. " used Lua command line:")

	local func, comp_err = loadstring(command, "console")

	if func then
		local result = {pcall(func)}
		if result[1] then
			table.remove(result, 1)
			print("---> Code successfully executed !", unpack(result))
			success = true
		else
			print("---> Error during execution :", result[2])
			success = false
		end
	else
		print("---> Error during compilation :", comp_err)
		success = false
	end

	local inputbox = ""
	for line in command:gmatch("[^\n]+") do
		if line:find("%-%-") ~= 1 then
			if inputbox:len() == 0 then
				inputbox = "-- " .. line
			else
				inputbox = inputbox .. "\n-- " .. line
			end
		else
			if inputbox:len() == 0 then
				inputbox = line
			else
				inputbox = inputbox .. "\n" .. line
			end
		end
	end

	local outputbox = "----------\n" .. table.concat(printed, "\n")

	me = nil
	here = nil
	print = old_print

	minetest.log("action", "End of Lua command logs")

	return success, outputbox, inputbox
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local name = player:get_player_name()
	if minetest.check_player_privs(name, {server = true}) then
		if fields.execute then
			local success, outputbox, inputbox = lua.run(fields.input, player)

			if fields.output:len() == 0 then
				lua.output_history[name] = outputbox
			else
				lua.output_history[name] = fields.output .. "\n" .. outputbox
			end

			lua.input_history[name] =inputbox

			minetest.show_formspec(name, "lua", get_formspec(name))
		else
			lua.input_history[name] = fields.input
			lua.output_history[name] = fields.output
		end
	end
end)
