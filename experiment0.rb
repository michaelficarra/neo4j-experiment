#!/tmp/jruby-1.6.1/bin/jruby
require "rubygems"
require "neography"
require "pp"

@@EDGE_COLOURS = %w[ 3F7A83 A1B05F 46433A FEA42C 33454E CE534D ]
@@VERTEX_COLOURS = %w[ A4B076 8AB5BF E8884D AC9569 6A7050 F7E988 E6F5A9 ]
@edge_colour_index = @vertex_colour_index = 0

@neo = Neography::Rest.new({ :server => '127.0.0.1', :port => 7474, :log_file => "neography.log", :log_enabled => true })


# Returns nodes that are related to a given node over the given relationships
#  along with the shortest path to those nodes from the given node.
# Yeah, that was a terrible description.
def possible_acquaintances(start_node, depth=4, relationships=[ {"type"=>"Knows", "direction"=>"out"}, {"type"=>"WorksAt", "direction"=>"all"} ])
	current_relationships = @neo.get_node_relationships(start_node).
		select { |relationship| relationship["type"] == "Knows" }
	current_friends = current_relationships.
		map { |relationship| relationship["end"] }

	traversals = @neo.traverse(
		start_node,
		"paths",
		{
			"order" => "breadth first",
			"uniqueness" => "node path",
			"relationships" => relationships,
			"return filter" =>
				{
					"language" => "builtin",
					"name" => "all but start node"
				},
			"depth" => depth
		}
	)

	relationships = traversals.
		reject { |traversal|
			current_friends.include? @neo.get_relationship(traversal["relationships"].last)["end"]
		}.
		map { |traversal| traversal["relationships"] }

	relationships.select do |path|
		@neo.get_node_properties(@neo.get_relationship(path.last)["end"])["type"] == "Person"
	end.group_by do |path|
		@neo.get_relationship(path.last)["end"]
	end.map do |path_group|
		path_group[1].min_by { |path| path.length }
	end.map do |path|
		{
			:dest => @neo.get_relationship(path.last)["end"],
			:path => path
		}
	end
end


def graph_possible_acquaintances(possibilities)
	puts "-> { weight: 4 }"

	node_colour_map = {}
	possibilities.each do |possibility|
		nodes = possibility[:path].map { |relationship| @neo.get_relationship(relationship)["start"] }
		nodes.push possibility[:dest]
		nodes.each do |node|
			unless node_colour_map.has_key? node
				node_colour_map[node] = @@VERTEX_COLOURS[@vertex_colour_index % @@VERTEX_COLOURS.length]
				@vertex_colour_index = @vertex_colour_index.next
			end
		end
	end

	node_colour_map.each do |node, colour|
		props = @neo.get_node_properties node
		puts "#{node.split("/").last} { color: ##{colour}, label: #{props["name"]}}"
	end

	possibilities.map { |_| _[:path] }.each do |path|
		node_props = @neo.get_node_properties @neo.get_relationship(path.last)["end"]
		node_props.delete "type"
		puts "; #{node_props.inspect}"
		path.each do |relationship|
			relationship = @neo.get_relationship relationship
			from   = relationship["start"].split("/").last
			to     = relationship["end"].split("/").last
			type   = relationship["type"]
			colour = @@EDGE_COLOURS[@edge_colour_index % @@EDGE_COLOURS.length]
			puts "#{from} -> #{to} { color: ##{colour}, label: #{type} }"
		end
		@edge_colour_index = @edge_colour_index.next
	end

	nil
end


def list_possible_acquaintances(possibilities)
	possibilities.
		map { |_| @neo.get_node_properties _[:dest] }.
		each { |_| pp _ }
	nil
end


def shortest_path(start_node, end_node, depth=10)
	@neo.get_path(
		start_node,
		end_node,
		[
			{ "type" => "Knows", "direction" => "out" },
			{ "type" => "WorksAt", "direction" => "all" }
		],
		depth,
		"shortestPath"
	)
end


def graph_shortest_path(path)
	puts "-> { weight: 7 }"
	start_id = path["start"].split("/").last
	end_id = path["end"].split("/").last
	puts "; shortest path from #{start_id} to #{end_id}"

	path["nodes"].each do |node|
		props  = @neo.get_node_properties node
		colour = @@VERTEX_COLOURS[@vertex_colour_index % @@VERTEX_COLOURS.length]
		@vertex_colour_index = @vertex_colour_index.next
		puts "#{node.split("/").last} { color: ##{colour}, label: #{props["name"]}}"
	end

	relationship_colour_map = {}
	path["relationships"].each do |relationship_str|
		relationship = @neo.get_relationship relationship_str
		from   = relationship["start"].split("/").last
		to     = relationship["end"].split("/").last
		type   = relationship["type"]
		unless relationship_colour_map.has_key? type
			relationship_colour_map[type] = @@EDGE_COLOURS[@edge_colour_index % @@EDGE_COLOURS.length]
			@edge_colour_index = @edge_colour_index.next
		end
		colour = relationship_colour_map[type]
		puts "#{from} -> #{to} { color: ##{colour}, label: #{type} }"
	end

	nil
end


possibilities = possible_acquaintances @neo.get_node(7)

	#list_possible_acquaintances possibilities
	graph_possible_acquaintances possibilities

path = shortest_path @neo.get_node(7), @neo.get_node(2)

	#graph_shortest_path path
