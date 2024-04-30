/**
* Name: MVehicle
* Description: defines the MVehicle species and its related constantes, variables, and methods.
* 				A MVehicle agent represents one vehicle that serves a bus line.
* Authors: Laatabi, Benchra
* For the i-Maroc project.
*/

model MVehicle
import "MarraSIM_V2_params.gaml"
import "MLine.gaml"

global {
	
	float V_TIME_DROP_IND <- 5#second;
	float V_TIME_TAKE_IND <- 10#second;
	
	int BUS_NORMAL_CAPACITY <- 50;
	int BUS_LARGE_CAPACITY <- 90;
	int BRT_CAPACITY <- 75;
	int TAXI_CAPACITY <- 6;
	
	// list of vehicles of urban/suburban lines
	list<BusVehicle> urban_busses <- [];
	list<BusVehicle> sub_urban_busses <- [];
	
	// update speed of suburban buslines whenever they in/out of the city
	reflex update_bus_speeds {
		ask sub_urban_busses {
			v_speed <- BUS_SUBURBAN_SPEED;
			v_in_city <- false;
		}
		ask sub_urban_busses overlapping city_area {
			v_speed <- traffic_on ? v_line.line_com_speed : BUS_URBAN_SPEED;
			v_in_city <- true;
		}
	}
}

/*******************************/
/**** MVehicle Species ******/
/*****************************/

species MVehicle skills: [moving] {
	MLine v_line;
	int v_current_direction;
	MStop v_current_stop;
	float v_speed;
	int v_capacity <- BUS_NORMAL_CAPACITY;
	MStop v_next_stop;
	point v_next_loc;
	float v_stop_wait_time <- -1.0;
	bool v_in_city <- true;
	
	list<Individual> v_passengers <- [];
		
	//---------------------------------------//
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
	
	//---------------------------------------//
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
			v_stop_wait_time <- v_line.line_type = LINE_TYPE_TAXI ? 0 : MIN_WAIT_TIME_STOP;
			v_current_stop <- v_next_stop;
				
			if v_in_city {
				
				/****************************** DROP ******************************/
				// drop off all passengers who have arrived to their destination
				int droppers <- 0; int transfers <- 0;
				ask v_passengers where (each.ind_current_trip.trip_end_stop = v_current_stop) { 
					
					if ind_trip_options at ind_current_trip != TRIP_FIRST {	// the passenger has arrived
						ind_times[ind_current_trip_index] <+ int(time); // final arrival time
						ind_arrived <- true;
						ind_moving <- false;
						droppers <- droppers + 1;
						
						if ind_current_trip.trip_end_stop != ind_destin_stop {
							int walked_dist <- ind_used_trips at ind_current_trip;
							walked_dist <- walked_dist + int(ind_destin_stop distance_to ind_current_trip.trip_end_stop);
							put walked_dist at: ind_current_trip in:ind_used_trips;
						}
					}
					else { // the passenger is making a connection (transfer)
						ind_times[ind_current_trip_index] <+ int(time); // arrival time for first trip
						ind_waiting_stop <- myself.v_current_stop;
						ind_waiting_stop.stop_waiting_people <+ self;
						ind_current_trip_index <- ind_current_trip_index + 1;
						ind_times <+ [int(time)]; // starting waiting time for the second trip
						transfers <- transfers + 1;
					}
					myself.v_passengers >- self;					
					myself.v_stop_wait_time <- myself.v_stop_wait_time + V_TIME_DROP_IND;
					
					/****************************************/	
					/**************** STATS ****************/
					list<int> itimes <- last(ind_times);
					if ind_current_trip.trip_line.line_type = LINE_TYPE_BUS {
						number_of_completed_bus_trips <- number_of_completed_bus_trips + 1;
						wtimes_completed_bus_trips <+ itimes[1] - itimes[0];
						triptimes_completed_bus_trips <+ itimes[2] - itimes[1];
					} else if ind_current_trip.trip_line.line_type = LINE_TYPE_BRT {
						number_of_completed_brt_trips <- number_of_completed_brt_trips + 1;
						wtimes_completed_brt_trips <+ itimes[1] - itimes[0];
						triptimes_completed_brt_trips <+ itimes[2] - itimes[1];
					} else {
						number_of_completed_taxi_trips <- number_of_completed_taxi_trips + 1;
						wtimes_completed_taxi_trips <+ itimes[1] - itimes[0];
						triptimes_completed_taxi_trips <+ itimes[2] - itimes[1];
					}
					/****************************************/	
					/***************************************/					
				}
				if (droppers + transfers) > 0 {
					write world.formatted_time() + v_line.line_name  + ' (' + v_current_direction + ') is dropping '
									+ (droppers + transfers) + ' people at ' + v_current_stop.stop_name color: #blue;
					if transfers > 0 {
						write '  -> Among them, ' + transfers + " are connecting" color: #darkblue;
					}
					write '  -> ' + length(v_passengers) + " people are on board" color: #darkorange;
				}
				
				/****************************** TAKE ******************************/
				// take the maximum number of passengers
				int n_individs <- v_capacity - length(v_passengers);
				int takens <- 0;
				list<Individual> waiting_individuals <- v_current_stop.stop_neighbors accumulate each.stop_waiting_people where(
									// if the individual is waiting at the next stop, don't take it
									(v_line.next_bs(v_current_direction, v_current_stop) = nil or
										each.ind_waiting_stop distance_to v_current_stop <
											each.ind_waiting_stop distance_to v_line.next_bs(v_current_direction, v_current_stop))
								and
									!empty(each.ind_trip_options.keys where (each.trip_line = self.v_line
										and each.trip_line_direction = self.v_current_direction
											and each.trip_start_stop in self.v_current_stop.stop_neighbors)));
				
				ask n_individs among waiting_individuals {
					// TODO select the best trip
					ind_current_trip <- one_of(ind_trip_options.keys where (each.trip_line = myself.v_line
												and each.trip_line_direction = myself.v_current_direction
												and each.trip_start_stop in myself.v_current_stop.stop_neighbors));
					takens <- takens + 1;
					myself.v_passengers <+ self;
					ind_waiting_stop.stop_waiting_people >- self;
					ind_times[ind_current_trip_index] <+ int(time); // end of waiting time, board time
					myself.v_stop_wait_time <- myself.v_stop_wait_time + V_TIME_TAKE_IND;
					
					// walking distance
					int walked_dist <- 0;
					if ind_current_trip.trip_start_stop != ind_waiting_stop {
						walked_dist <- int(ind_waiting_stop distance_to ind_current_trip.trip_start_stop);
					}
					ind_used_trips <+ ind_current_trip::walked_dist;
				}	
				if takens > 0 {
					write world.formatted_time() + v_line.line_name  + ' (' + v_current_direction + ') is taking ' + takens + ' people at ' + v_current_stop.stop_name color: #darkgreen;
					write '  -> Passengers : ' + length(v_passengers) + " people are on board" color: #darkorange;
				}
			}
			
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
		
		do goto target: v_next_loc speed: v_speed
					on: v_current_direction = DIRECTION_OUTGOING ? v_line.line_outgoing_graph : v_line.line_return_graph;
	}
}

species BusVehicle parent: MVehicle {
	float v_speed <- BUS_URBAN_SPEED;
	image_file v_icon <- image_file("../../includes/img/bus.png");
	geometry shape <- envelope(v_icon);
	
	aspect default {
		draw v_icon size: {120#meter,60#meter} rotate: heading;
	}
}

species BRTVehicle parent: MVehicle {
	float v_speed <- BRT_SPEED;
	int v_capacity <- BRT_CAPACITY;
	image_file v_icon <- image_file("../../includes/img/BRT.png");
	geometry shape <- envelope(v_icon);
	
	aspect default {
		draw v_icon size: {120#meter,60#meter} rotate: heading;
	}
}	

species TaxiVehicle parent: MVehicle {
	float v_speed <- TAXI_SPEED;
	int v_capacity <- TAXI_CAPACITY;
	
	image_file v_icon <- image_file("../../includes/img/taxi.png");
	geometry shape <- envelope(v_icon);
	
	aspect default {
		draw v_icon size: {100#meter,50#meter} rotate: heading;
	}
}

/*** end of species definition ***/