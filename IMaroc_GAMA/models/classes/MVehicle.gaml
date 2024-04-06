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
	
	// speed of busses in the urban area
	float URBAN_SPEED <- 30#km/#hour;
	// speed of busses in the suburban area
	float SUBURBAN_SPEED <- 60#km/#hour;
	// the minimum wait time at bus stops
	float MIN_WAIT_TIME_STOP <- 120#second;
	
}

/*******************************/
/**** BusVehicle Species ******/
/*****************************/

species MVehicle skills: [moving] {
	MLine v_line;
	int v_current_direction;
	MStop v_current_stop;
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

		speed <- !empty(PDUZone overlapping self) ? v_line.line_com_speed : SUBURBAN_SPEED;
		
		if v_current_direction = DIRECTION_OUTGOING {
			do goto target: v_next_loc on: v_line.line_outgoing_graph; 
		}
		else {
			do goto target: v_next_loc on: v_line.line_return_graph; 
		}
	}
}

species BusVehicle parent: MVehicle {
	image_file v_icon <- image_file("../../includes/img/bus.png");
	aspect default {
		draw v_icon size: {100#meter,50#meter} rotate: heading;
	}
}

species BRTVehicle parent: MVehicle {
	image_file brt_icon <- image_file("../../includes/img/BRT.png");
	aspect default {
		draw brt_icon size: {100#meter,50#meter} rotate: heading;
	}
}	

species TaxiVehicle parent: MVehicle {
	image_file taxi_icon <- image_file("../../includes/img/taxi.png");
	aspect default {
		draw shape size: {80#meter,40#meter} rotate: heading;
	}
}

/*** end of species definition ***/