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
	
	int DEFAULT_NUMBER_BUS <- 4;
	int DEFAULT_NUMBER_BRT <- 2;
	int DEFAULT_NUMBER_TAXI <- 10;
	
	float DEFAULT_BUS_INTERVAL_TIME <- 20#minute;
	float DEFAULT_TAXI_INTERVAL_TIME <- 10#minute;
}

/*******************************/
/******* MLine Species ******/
/*****************************/

species MLine schedules: [] parallel: true {
	int line_id;
	string line_name;
	int line_type;
	float line_com_speed <- BUS_URBAN_SPEED;
	float line_interval_time_m <- DEFAULT_BUS_INTERVAL_TIME;
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
			loop i from: 0 to: num-1 {
				create BusVehicle {
					do init_vehicle(myself, direction);
					v_stop_wait_time <- (myself.line_interval_time_m * i);
					if traffic_on {
						v_speed <- myself.line_com_speed;
					}
				}
			}
		} else if self.line_type = LINE_TYPE_BRT {
			loop i from: 0 to: num-1 {
				create BRTVehicle {
					do init_vehicle(myself, direction);
					v_stop_wait_time <- (myself.line_interval_time_m * i);
				}
			}
		} else if self.line_type = LINE_TYPE_TAXI {
			loop i from: 0 to: num-1 {
				create TaxiVehicle {
					do init_vehicle(myself, direction);
					v_stop_wait_time <- (myself.line_interval_time_m * i);
				}
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
	
	//---------------------------------------//
	// return the next stop given the direction and another stop
	MStop next_bs (int dir, MStop ss) {
		if dir = DIRECTION_OUTGOING {
			int indx <- line_outgoing_stops.keys index_of ss;
			return indx < length(line_outgoing_stops.keys)-1 ? line_outgoing_stops.keys[indx+1] : nil;
		} else {
			int indx <- line_return_stops.keys index_of ss;
			return indx < length(line_return_stops.keys)-1 ? line_return_stops.keys[indx+1] : nil;
		}
	}	
}

species BusLine parent: MLine {
	
	init {
		line_type <- LINE_TYPE_BUS;
	}
	
	aspect default {
		draw (shape+10#meter) color: #gamablue;
		draw (shape+5#meter) color: #white;
		loop ms over: line_outgoing_stops.values{
			draw square(30#meter) color:#red at: ms;
		}
		loop ms over: line_return_stops.values{
			draw square(30#meter) color:#yellow at: ms;
		}
	}
}

species BRTLine parent: MLine {
	
	init {
		line_type <- LINE_TYPE_BRT;
	}
	
	aspect default {
		draw (shape+10#meter) color: #darkred;
		draw (shape+5#meter) color: #white;
	}	
}

species TaxiLine parent: MLine {
	
	init {
		line_type <- LINE_TYPE_TAXI;
		line_interval_time_m <- DEFAULT_TAXI_INTERVAL_TIME;
	}
	
	aspect default {
		draw (shape+10#meter) color: #darkgreen;
		draw (shape+5#meter) color: #white;
	}
}

/*** end of species definition ***/
