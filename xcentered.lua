local directions = {
	{x = 1, y = 0, z = 0},
	{x = 0, y = 0, z = 1},
	{x = -1, y = 0, z = 0},
	{x = 0, y = 0, z = -1},
}


xcentered = {}

-- this table contains the new postfix and param2 for a newly placed node
-- depending on its neighbours
local xcentered_get_candidate = {};
-- no neighbours
xcentered_get_candidate[0]  = {"_c0", 0 };
-- exactly one neighbour
xcentered_get_candidate[1]  = {"_c1", 1 };
xcentered_get_candidate[2]  = {"_c1", 0 };
xcentered_get_candidate[4]  = {"_c1", 3 };
xcentered_get_candidate[8]  = {"_c1", 2 };
-- a line between two nodes
xcentered_get_candidate[5]  = {"_c_line", 1 };
xcentered_get_candidate[10] = {"_c_line", 0 };
-- two neighbours
xcentered_get_candidate[3]  = {"_c2", 0 };
xcentered_get_candidate[6]  = {"_c2", 3 };   
xcentered_get_candidate[12] = {"_c2", 2 };
xcentered_get_candidate[9]  = {"_c2", 1 };
-- three neighbours
xcentered_get_candidate[7]  = {"_c3", 3 };
xcentered_get_candidate[11] = {"_c3", 0 }; 
xcentered_get_candidate[13] = {"_c3", 1 };
xcentered_get_candidate[14] = {"_c3", 2 };
-- four neighbours
xcentered_get_candidate[15] = {"_c4", 1 };



xcentered_update_one_node = function( pos, name, digged )
	if( not( pos ) or not( name) or not( minetest.registered_nodes[name])) then
		return;
	end

	local candidates = {0,0,0,0};
	local id   = 0;
	local pow2 = {1,2,4,8};
	for i, dir in pairs(directions) do
		local node = minetest.get_node( {x=pos.x+dir.x, y=pos.y, z=pos.z+dir.z });
		if(    node
		   and node.name
		   and minetest.registered_nodes[node.name] ) then
	
			-- nodes that drop the same are considered similar xcentered nodes
			if( minetest.registered_nodes[node.name].drop == name  ) then
				candidates[i] = 1;
				id = id+pow2[i];
			end
		end
	end
	if( digged ) then
		return candidates;
	end
	local new_node = xcentered_get_candidate[ id ];
	if( new_node and new_node[1] ) then
		local new_name = string.sub( name, 1, string.len( name )-3 )..new_node[1];
		if(     new_name and minetest.registered_nodes[ new_name ]) then
			minetest.swap_node( pos, {name=new_name, param2=new_node[2] });
		-- if no central node without neighbours is defined, take the c4 variant
		elseif( new_node[1]=='_c0' and not( minetest.registered_nodes[ new_name ])) then
			minetest.swap_node( pos, {name=name,     param2=0 });
		end
	end
	return candidates;
end


xcentered_update = function( pos, name, active, has_been_digged )
	if( not( pos ) or not( name) or not( minetest.registered_nodes[name])) then
		return;
	end

	local c = xcentered_update_one_node( pos, name, has_been_digged );
	for j,dir2 in pairs(directions) do
		if( c[j]==1 ) then
			xcentered_update_one_node( {x=pos.x+dir2.x, y=pos.y, z=pos.z+dir2.z}, name, false );
		end
	end		
end

-- def: that part of the node definition that is shared between all nodes
-- node_box_data: has to be a table that contains defs for   "c0", "c1", "c2", "c3", "c4", "c_line"
-- c<nr>: node is connected to that many neighbours clockwise
-- c_line: node has 2 neighbours at opposite ends and forms a line with them
xcentered.register = function( name, def, node_box_data, selection_box_data )

	for k,v in pairs( node_box_data ) do 
		-- some common values for all xcentered nodes; can be changed by def_common or node_defs if needed
		def.drawtype   = "nodebox";
		def.paramtype  = "light";
		def.paramtype2 = "facedir";
		-- similar xcentered nodes are identified by having the same drop
		def.drop = name.."_c4";
		-- nodebox and selection box have been calculated using smmyetry
		def.node_box = {
			type = "fixed",
			fixed = node_box_data[k],
		};
		def.selection_box = {
			type = "fixed",
			fixed = selection_box_data[k],
		};
		if( not( def.tiles )) then
			def.tiles = def.textures;
		end
		local new_def = minetest.deserialize( minetest.serialize( def ));
		if( k=='c4' ) then
			-- update nodes when needed
			new_def.on_construct = function( pos )
				return xcentered_update( pos, name.."_c4", true, nil );
			end
		else
			-- avoid spam in creative inventory
			new_def.groups.not_in_creative_inventory = 1;
		end
		-- update neighbours when this node is dug
		new_def.after_dig_node = function(pos, oldnode, oldmetadata, digger)
			return xcentered_update( pos, name.."_c4", true, true );
		end

		-- actually register the node
		minetest.register_node( name.."_"..k, new_def );
	end
end


-- make use of the symmetry of the nodes and calculate the nodeboxes that way
-- (may also be used for collusion boxes);
-- the center_node_box_list is shared by all nodes that have nighbours
xcentered.construct_node_box_data = function( node_box_list, center_node_box_list, node_box_line )
	local res = {};
	res.c1 = {};
	res.c2 = {};
	res.c3 = {};
	res.c4 = {};

	-- start with the node that is only connected to one neighbour
	for _,v in pairs( node_box_list ) do
		-- the node c1 already contains all nodes rotated the right way
		table.insert( res.c1, v );
		table.insert( res.c2, v );
		table.insert( res.c3, v );
		table.insert( res.c4, v );
	end

	-- this node is connected to two neighbours and forms a curve/corner;
	-- it keeps the nodes from above plus..
	for _,v in pairs( node_box_list ) do
		-- swap x and z - we are working on a corner node
		table.insert( res.c2, {v[3], v[2], v[1],    v[6], v[5], v[4]});
		table.insert( res.c3, {v[3], v[2], v[1],    v[6], v[5], v[4]});
		table.insert( res.c4, {v[3], v[2], v[1],    v[6], v[5], v[4]});
	end
	
	-- now we have a t-crossing
	for _,v in pairs( node_box_list ) do
		-- mirror x
		table.insert( res.c3, {v[4], v[2], v[3]-0.5,  v[1], v[5], v[5]-0.5});
		table.insert( res.c4, {v[4], v[2], v[3]-0.5,  v[1], v[5], v[5]-0.5});
	end

	-- ...and now a node which is connected to four neighbours
	for _,v in pairs( node_box_list ) do
		-- swap x and z and mirror
		table.insert( res.c4, {v[3]-0.5, v[2], v[4],    v[6]-0.5, v[5], v[1]});
	end

	res.c0 = {};
	for _,v in pairs( center_node_box_list ) do
		table.insert( res.c0, v );
		table.insert( res.c1, v );
		table.insert( res.c2, v );
		table.insert( res.c3, v );
		table.insert( res.c4, v );
	end	

	-- no center node
	if( #res.c0 < 1 ) then
		res.c0 = nil;
	end

	res.c_line = node_box_line;
	return res;
end


-- emulate xpanes
xcentered.register_pane = function( name, def )
	local node_box_data = 
		xcentered.construct_node_box_data( {{-1/32, -0.5, 0,     1/32, 0.5, 0.5}}, {}, {{-1/32, -0.5, -0.5,  1/32, 0.5, 0.5}});
	local selection_box_data = 
		xcentered.construct_node_box_data( {{-0.06, -0.5, 0,     0.06, 0.5, 0.5}}, {}, {{-0.06, -0.5, -0.5,  0.06, 0.5, 0.5}});
	xcentered.register( 'mccompat:'..name,
		def,
		-- node boxes (last one: full one)
		node_box_data,
		-- selection boxes (last one: full one)
		selection_box_data
		);
-- TODO: register_craft would be needed as well
end


xcentered.register_pane("xwood", {
	description = "xwood",
	tiles = {"default_wood.png"},
--	drawtype = "nodebox",
--	paramtype = "light",
--	is_ground_content = false,
--	sunlight_propagates = true,
--	walkable = false,
--	pointable = false,
--	diggable = false,
--	buildable_to = true,
--	air_equivalent = true,
	textures = {"default_wood.png"},
	groups = {snappy=2, cracky=3, oddly_breakable_by_hand=3, pane=1},
--	sounds = default.node_sound_stone_defaults(),
--	recipe = {
--		{'default:steel_ingot', 'default:steel_ingot', 'default:steel_ingot'},
--		{'default:steel_ingot', 'default:steel_ingot', 'default:steel_ingot'}
	});