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
	float MIN_WAIT_TIME_BS <- 180#second;
	
}

/*******************************/
/**** BusVehicle Species ******/
/*****************************/

species MVehicle skills: [moving] {
	MLine v_line;
	int v_current_direction;
	MStop v_current_bs;
	MStop v_next_bs;
	point v_next_loc;
	float v_stop_wait_time <- -1.0;
	bool v_in_city <- true;
	image_file v_icon <- image_file("../../includes/img/bus.png");
	geometry shape <- envelope(v_icon);
	
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
			v_stop_wait_time <- MIN_WAIT_TIME_BS;
			v_current_bs <- v_next_bs;
				
			// to know the next stop
			if v_current_direction = DIRECTION_OUTGOING { // outgoing
				if v_current_bs = last(v_line.line_outgoing_stops.keys) { // last outgoing stop
					v_current_direction <- DIRECTION_RETURN;
					v_next_bs <- v_line.line_return_stops.keys[0];
					v_next_loc <- v_line.line_return_stops at v_next_bs;
				} else {
					v_next_bs <- v_line.line_outgoing_stops.keys[(v_line.line_outgoing_stops.keys index_of v_next_bs) + 1];
					v_next_loc <- v_line.line_outgoing_stops at v_next_bs;
				}
			} else { // return
				if v_current_bs = last(v_line.line_return_stops.keys) { // last return stop
					v_current_direction <- DIRECTION_OUTGOING;
					v_next_bs <- v_line.line_outgoing_stops.keys[0];
					v_next_loc <- v_line.line_outgoing_stops at v_next_bs;
				} else {
					v_next_bs <- v_line.line_return_stops.keys[(v_line.line_return_stops.keys index_of v_next_bs) + 1];
					v_next_loc <- v_line.line_return_stops at v_next_bs;
				}
			}
			return;
		}

		speed <- !empty(PDUZone overlapping self) ? v_line.line_com_speed : SUBURBAN_SPEED;
		
		if v_current_direction = DIRECTION_OUTGOING {
			//do follow path: v_line.bl_outgoing_path;
			do goto target:v_next_loc on: v_line.line_outgoing_path;
		}
		if v_current_direction = DIRECTION_RETURN {
			//do follow path: v_line.bl_return_path;
			do goto target:v_next_loc on: v_line.line_return_path;
		}
	}
	
	//
}

species BusVehicle parent: MVehicle {
	aspect default {
		draw v_icon size: {50#meter,25#meter} rotate: heading;
	}
}

species BRTVehicle parent: MVehicle {	
	aspect default {
		draw rectangle(50#meter,25#meter) color: #cyan rotate: heading;
	}
}	

species TaxiVehicle parent: MVehicle {
	aspect default {
		draw rectangle(40#meter,20#meter) color: #green rotate: heading;
	}
}

/*** end of species definition ***/