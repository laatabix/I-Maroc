/**
* Name: MLine
* Description: defines the MLine species and its related constantes, variables, and methods.
* 				A MLine agent represents an outgoing-return path of a bus.
* Authors: Laatabi, Benchra
* For the i-Maroc project.
*/

model MLine

import "MVehicle.gaml"
import "MStop.gaml"

global {
	
	int LINE_TYPE_BUS <- 21;
	int LINE_TYPE_BRT <- 22;
	int LINE_TYPE_TAXI <- 23;
	
	int DEFAULT_NUMBER_BUS <- 2;
	int DEFAULT_NUMBER_BRT <- 2;
	int DEFAULT_NUMBER_TAXI <- 2;
}

/*******************************/
/******* MLine Species ******/
/*****************************/

species MLine schedules: [] parallel: true {
	int line_id;
	string line_name;
	int line_type;
	float line_com_speed <- BUS_URBAN_SPEED;
	map<MStop,point> line_outgoing_stops <- []; // list of bus stops on an outgoing path
	map<MStop,point> line_return_stops <- []; // bus stops on the return path
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
		if self.line_type = LINE_TYPE_BUS {
			create BusVehicle number: num {
				do init_vehicle(myself, direction);
			}
		} else if self.line_type = LINE_TYPE_BRT {
			create BRTVehicle number: num {
				do init_vehicle(myself, direction);
			}
		} else if self.line_type = LINE_TYPE_TAXI {
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
			if !(mstop.stop_lines contains (self::DIRECTION_OUTGOING)) {
				mstop.stop_lines <+ self::DIRECTION_OUTGOING;
			}
		} else {
			if length(self.line_return_stops) != stop_order {
				write "Error in order of stops!" color: #red;
			}
			self.line_return_stops <+ mstop::mypoints closest_to mstop;
			if !(mstop.stop_lines contains (self::DIRECTION_RETURN)) {
				mstop.stop_lines <+ self::DIRECTION_RETURN;
			}
		}
	}
	
	//---------------------------------------//
	// test whether the line can link two bus stops or not
	int can_link_stops (MStop origin_stop, MStop destin_stop) {
		int o_ix <- line_outgoing_stops.keys index_of origin_stop;
		int d_ix <- line_outgoing_stops.keys index_of destin_stop;
		
		if o_ix != -1 and d_ix != -1 and o_ix < d_ix {
			return DIRECTION_OUTGOING;
		} else {
			o_ix <- line_return_stops.keys index_of origin_stop;
			d_ix <- line_return_stops.keys index_of destin_stop;
			if o_ix != -1 and d_ix != -1 and o_ix < d_ix {
				return DIRECTION_RETURN;
			}
		}
		return -1;
	}	
}

species BusLine parent: MLine {
	int line_type <- LINE_TYPE_BUS;
	
	aspect default {
		draw (shape+10#meter) color: #gamablue;
		draw (shape+5#meter) color: #white;
	}
	
	
}

species BRTLine parent: MLine {
	int line_type <- LINE_TYPE_BRT;
	
	aspect default {
		draw (shape+10#meter) color: #darkred;
		draw (shape+5#meter) color: #white;
	}	
}

species TaxiLine parent: MLine {
	int line_type <- LINE_TYPE_TAXI;
	list<MStop> tl_connected_stops_outgoing <- [];
	list<MStop> tl_connected_stops_return <- [];
	
	aspect default {
		draw (shape+10#meter) color: #darkgreen;
		draw (shape+5#meter) color: #white;
	}
	
	int can_link_stops (MStop origin_stop, MStop destin_stop) {
		try {
			point arrival_stop <- last(line_outgoing_stops);
			point ostop <- origin_stop.stop_connected_taxi_lines at (self::DIRECTION_OUTGOING);
			point dstop <- destin_stop.stop_connected_taxi_lines at (self::DIRECTION_OUTGOING);
			float o_dis <- path_between(line_outgoing_graph, ostop, arrival_stop).shape.perimeter;
			float d_dis <- path_between(line_outgoing_graph, dstop, arrival_stop).shape.perimeter;
			if d_dis < o_dis {
				return DIRECTION_OUTGOING;
			} else {
				arrival_stop <- last(line_return_stops);
				ostop <- origin_stop.stop_connected_taxi_lines at (self::DIRECTION_RETURN);
				dstop <- destin_stop.stop_connected_taxi_lines at (self::DIRECTION_RETURN);
				o_dis <- path_between(line_return_graph, ostop, arrival_stop).shape.perimeter;
				d_dis <- path_between(line_return_graph, dstop, arrival_stop).shape.perimeter;
				if d_dis < o_dis {
					return DIRECTION_RETURN;
				}
			}
			return -1;
		} catch {
			return -1;	
		}
	}		
}

/*** end of species definition ***/
