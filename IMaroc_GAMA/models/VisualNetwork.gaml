/**
* Name: VisualNetwork
* Based on the internal skeleton template. 
* Author: Laatabi
* Tags: 
*/

model VisualNetwork

global {
	file marrakesh_pdu <- shape_file("../includes/gis/PDU_zoning/zonage_pdu.shp"); 
	file bus_network <- shape_file("../includes/gis/bus_network/bus_lines.shp");
	file marrakesh_bus_stops <- shape_file("../includes/gis/bus_network/bus_stops.shp");
	file taxi_network <- shape_file("../includes/gis/taxi_network/taxi_lines.shp");
	
	geometry shape <- envelope (bus_network);
	
	int BL_DIRECTION_OUTGOING <- 1;
	int BL_DIRECTION_RETURN <- 2;
	
	init {
		
		create PDUZone from: marrakesh_pdu with: [pduz_code::int(get("id")), pduz_name::get("label")];
		create dummy_geom from: bus_network with: [g_name::get("NAME"),g_direction::int(get("DIR"))];
		create BusStop from: marrakesh_bus_stops with: [bs_id::int(get("stop_numbe")), bs_name::get("stop_name")]{
			bs_zone <- first(PDUZone overlapping self);
		}
		
		/*matrix dataMatrix <- matrix(csv_file("../includes/gis/network/bus_lines_stops.csv",true));
		loop i from: 0 to: dataMatrix.rows -1 {
			string bus_line_name <- dataMatrix[0,i];
			
			// create the bus line if it does not exist yet
			BusLine current_bl <- BusLine first_with (each.bl_name = bus_line_name);
			
			if current_bl = nil {
				create BusLine returns: my_busline {
					bl_name <- bus_line_name;
					bl_outgoing_geom <- dummy_geom first_with (each.g_name = bl_name and each.g_direction = BL_DIRECTION_OUTGOING);
					bl_return_geom <- dummy_geom first_with (each.g_name = bl_name and each.g_direction = BL_DIRECTION_RETURN);
					shape <- bl_outgoing_geom + bl_return_geom;
				}
				current_bl <- my_busline[0];
			}
			BusStop current_bs <- BusStop first_with (each.bs_id = int(dataMatrix[3,i]));
			if current_bs != nil {
				if int(dataMatrix[1,i]) = BL_DIRECTION_OUTGOING {
					if length(current_bl.bl_outgoing_bs) != int(dataMatrix[2,i]) {
						write "Error in order of bus stops!" color: #red;
					}
					current_bl.bl_outgoing_bs <+ current_bs::current_bl.bl_outgoing_geom.points closest_to current_bs;
				} else {
					if length(current_bl.bl_return_bs) != int(dataMatrix[2,i]) {
						write "Error in order of bus stops!" color: #red;
					}
					current_bl.bl_return_bs <+ current_bs::current_bl.bl_return_geom.points closest_to current_bs;
				}
			} else {
				write "Error, the bus stop does not exist : " + dataMatrix[3,i] + " (" + dataMatrix[1,i] +")" color: #red;
				return;
			}	
		}*/
		
		ask dummy_geom {
			do die;
		}
		
		/******************/
		create TaxiLine from: taxi_network with: [tl_name::get("ID_TXLINE")];//,g_direction::int(get("DIR"))];
	}
}

species dummy_geom {
	string g_name;
	int g_direction;
}

species TaxiLine schedules: [] {
	string tl_name;
	
	geometry tl_outgoing_geom;
	geometry tl_return_geom;
	
	TaxiStation tl_start_ts;
	TaxiStation tl_end_ts;	
	
	rgb tl_color <- rnd_color(254);	
	
	aspect default {
		draw (shape+1#meter) color: #gold;
		draw (shape+3#meter) color: tl_color;
		
		/*draw square(20#meter) color: #gold at: tl_start_ts.location;
		draw square(10#meter) color: tl_color at: tl_start_ts.location;
		
		draw square(20#meter) color: #gold at: tl_end_ts.location;
		draw square(10#meter) color: tl_color at: tl_end_ts.location;*/	
	}
}

species TaxiStation schedules: [] {
	int ts_id;
	string bs_name;
	PDUZone bs_zone;
}


species BusLine schedules: [] {
	string bl_name;
	
	geometry bl_outgoing_geom;
	geometry bl_return_geom;
	
	map<BusStop,point> bl_outgoing_bs <- [];	
	map<BusStop,point> bl_return_bs <- [];	
	
	rgb bl_color <- rnd_color(254);	
	
	aspect default {
		draw (shape+1#meter) color: #white;
		draw (shape+3#meter) color: bl_color;
		
		loop bs over: bl_outgoing_bs.keys {
			draw square(20#meter) color: #black at: bl_outgoing_bs at bs;
			draw square(10#meter) color: bl_color at: bl_outgoing_bs at bs;	
		}
		
		loop bs over: bl_return_bs.keys {
			draw square(20#meter) color: #black at: bl_return_bs at bs;
			draw square(10#meter) color: bl_color at: bl_return_bs at bs;	
		} 
	}
}

species BusStop schedules: [] {
	int bs_id;
	string bs_name;
	PDUZone bs_zone;
}

species PDUZone schedules: [] {
	int pduz_code;
	string pduz_name;
	
	aspect default {
		draw shape color: #whitesmoke border: #lightgray;
	}
}

experiment VisualNetwork type: gui {
	/** Insert here the definition of the input and output of the model */
	output {
		
		/*display Region type: opengl background: #white {
			
			species PDUZone;
			//species BusLine;
		}*/
		
		display City type: opengl background: #white {
			camera 'default' location: {76712.1365,71872.4373,24002.274} target: {76712.1365,71872.0184,0.0};
			
			species PDUZone refresh: false;
			//species BusLine refresh: false;
			species TaxiLine refresh: false;
		}
		
	}
}
