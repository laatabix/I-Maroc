/**
* Name: BusLine
* Description: defines the BusLine species and its related constantes, variables, and methods.
* 				A BusLine agent represents an outgoing-return path of a bus.
* Authors: Laatabi, Benchra
* For the i-Maroc project.
*/

model MLine

import "MVehicle.gaml"
import "MStop.gaml"

global {
		
	// colors to color bus lines when displayed
	//list<rgb> BL_COLORS <- [#darkblue,#darkcyan,#darkgoldenrod,#darkgray,#darkkhaki,#darkmagenta,#darkolivegreen,#darkorchid,
	//							#darksalmon,#darkseagreen,#darkslateblue,#darkslategray,#darkturquoise,#darkviolet];

	//font LFONT0 <- font("Arial", 5, #bold);
}

/*******************************/
/******* MLine Species ******/
/*****************************/

species MLine schedules: [] parallel: true {
	int line_id;
	string line_name;
	float line_com_speed <- BUS_URBAN_SPEED;
	map<MStop,point> line_outgoing_stops <- []; // list of bus stops on an outgoing path
	map<MStop,point> line_return_stops <- []; // bus stops on the return path
	//rgb bl_color <- one_of(BL_COLORS);
	geometry line_outgoing_shape;	
	geometry line_return_shape;
	graph line_outgoing_graph;	
	graph line_return_graph;
		
	//---------------------------------------//
	action init_line (string nm, geometry out, geometry ret) {
		line_name <- nm;
		line_outgoing_shape <- out;
		line_return_shape <- ret;
		line_outgoing_graph <- as_edge_graph(to_segments(line_outgoing_shape));
		line_return_graph <- as_edge_graph(to_segments(line_return_shape));
		shape <- line_outgoing_shape + line_return_shape;
	}
	
	//---------------------------------------//
	action create_vehicles (int num, int direction) {
		if species_of(self) = BusLine {
			create BusVehicle number: num {
				do init_vehicle(myself, direction);
			}
		} else if species_of(self) = BRTLine {
			create BRTVehicle number: num {
				do init_vehicle(myself, direction);
			}
		} else if species_of(self) = TaxiLine {
			create TaxiVehicle number: num {
				do init_vehicle(myself, direction);
			}
		}
	}
	
	//---------------------------------------//
	action add_stop (int direction, MStop mstop, int stop_order, list<point> mypoints) {
		if direction = DIRECTION_OUTGOING {
			if length(self.line_outgoing_stops) != stop_order {
				write "Error in order of stops!" color: #red;
			}
			self.line_outgoing_stops <+ mstop::mypoints closest_to mstop;
		} else {
			if length(self.line_return_stops) != stop_order {
				write "Error in order of stops!" color: #red;
			}
			self.line_return_stops <+ mstop::mypoints closest_to mstop;
		}
	}
}

species BusLine parent: MLine {

	aspect default {
		draw (shape+10#meter) color: #gamablue;
		draw (shape+5#meter) color: #white;
	}	
}

species BRTLine parent: MLine {

	aspect default {
		draw (shape+10#meter) color: #darkred;
		draw (shape+5#meter) color: #white;
	}	
}

species TaxiLine parent: MLine {
	
	aspect default {
		draw (shape+10#meter) color: #darkgreen;
		draw (shape+5#meter) color: #white;
	}
}

/*** end of species definition ***/
