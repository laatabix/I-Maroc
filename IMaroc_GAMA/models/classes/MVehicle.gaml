/**
* Name: BusVehicle
* Description: defines the BusVehicle species and its related constantes, variables, and methods.
* 				A BusVehicle agent represents one vehicle that serves a bus line.
* Authors: Laatabi
* For the i-Maroc project.
*/

model MVehicle
import "../MarraSIM_V2_params.gaml"
import "MLine.gaml"

global {
	
	list<BusVehicle> sub_urban_vehicles <- [];

	// speed of busses in the urban area
	float BUS_URBAN_SPEED <- 30#km/#hour;
	// speed of BRTs and Taxis
	float BRT_SPEED <- 40#km/#hour;
	float TAXI_SPEED <- 40#km/#hour;
	
	// speed of busses in the suburban area
	float BUS_SUBURBAN_SPEED <- 60#km/#hour;
	
	// the minimum wait time at bus stops
	float MIN_WAIT_TIME_STOP <- 120#second;
	
	// update speed of suburban buslines whenever they in/out of the city
	reflex update_bus_speeds {
		ask sub_urban_vehicles {
			v_speed <- BUS_SUBURBAN_SPEED;
		}
		ask sub_urban_vehicles overlapping city_area {
			v_speed <- v_line.line_com_speed;
		}
	}
	
}

/*******************************/
/**** BusVehicle Species ******/
/*****************************/

species MVehicle skills: [moving] {
	MLine v_line;
	int v_current_direction;
	MStop v_current_stop;
	float v_speed;
	MStop v_next_stop;
	point v_next_loc;
	float v_stop_wait_time <- -1.0;
	bool v_in_city <- true;
	
	action init_vehicle (MLine mline, int direc) {
		v_line <- mline;
		v_current_direction <- direc;	
		if v_current_direction = DIRECTION_OUTGOING {
			v_current_stop <- v_line.line_outgoing_stops.keys[0];
			location <- v_line.line_outgoing_stops.values[0];
		} else {
			v_current_stop <- v_line.line_return_stops.keys[0];
			location <- v_line.line_return_stops.values[0];
		}
		v_next_stop <- v_current_stop;
		v_next_loc <- location;
	}
	
	reflex drive {
		// if the bus has to wait
		if v_stop_wait_time > 0 {
			v_stop_wait_time <- v_stop_wait_time - step;
			return;
		}
		// if the waiting time is over
		if v_stop_wait_time = 0 {
			v_stop_wait_time <- -1.0;
		}
		// the bus has reached its next bus stop
		if location overlaps (10#meter around v_next_loc) {
			v_stop_wait_time <- MIN_WAIT_TIME_STOP;
			v_current_stop <- v_next_stop;
				
			// to know the next stop
			if v_current_direction = DIRECTION_OUTGOING { // outgoing
				if v_current_stop = last(v_line.line_outgoing_stops.keys) { // last outgoing stop
					v_current_direction <- DIRECTION_RETURN;
					v_next_stop <- v_line.line_return_stops.keys[0];
					v_next_loc <- v_line.line_return_stops at v_next_stop;
				} else {
					v_next_stop <- v_line.line_outgoing_stops.keys[(v_line.line_outgoing_stops.keys index_of v_next_stop) + 1];
					v_next_loc <- v_line.line_outgoing_stops at v_next_stop;
				}
			} else { // return
				if v_current_stop = last(v_line.line_return_stops.keys) { // last return stop
					v_current_direction <- DIRECTION_OUTGOING;
					v_next_stop <- v_line.line_outgoing_stops.keys[0];
					v_next_loc <- v_line.line_outgoing_stops at v_next_stop;
				} else {
					v_next_stop <- v_line.line_return_stops.keys[(v_line.line_return_stops.keys index_of v_next_stop) + 1];
					v_next_loc <- v_line.line_return_stops at v_next_stop;
				}
			}
			return;
		}

		if v_current_direction = DIRECTION_OUTGOING {
			do goto target: v_next_loc on: v_line.line_outgoing_graph speed: v_speed; 
		}
		else {
			do goto target: v_next_loc on: v_line.line_return_graph speed: v_speed; 
		}
	}
}

species BusVehicle parent: MVehicle {
	image_file v_icon <- image_file("../../includes/img/bus.png");
	geometry shape <- envelope(v_icon);

	init {
		v_speed <- BUS_URBAN_SPEED;
	}
	
	aspect default {
		draw v_icon size: {120#meter,60#meter} rotate: heading;
	}
}

species BRTVehicle parent: MVehicle {
	image_file v_icon <- image_file("../../includes/img/BRT.png");
	geometry shape <- envelope(v_icon);
	
	init {
		v_speed <- BRT_SPEED;
	}
	
	aspect default {
		draw v_icon size: {120#meter,60#meter} rotate: heading;
	}
}	

species TaxiVehicle parent: MVehicle {
	image_file v_icon <- image_file("../../includes/img/taxi.png");
	geometry shape <- envelope(v_icon);
	
	init {
		v_speed <- TAXI_SPEED;
	}
	
	aspect default {
		draw v_icon size: {100#meter,50#meter} rotate: heading;
	}
}

/*** end of species definition ***/