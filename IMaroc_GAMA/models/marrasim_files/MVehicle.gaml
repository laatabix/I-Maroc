/**
* Name: MVehicle
* Description: defines the MVehicle species and its related constantes, variables, and methods.
* 				A MVehicle agent represents one vehicle that serves a bus line.
* Authors: Laatabi
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
		ask sub_urban_busses where (first(each.v_current_stops).stop_zone != nil) {
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
	list<MStop> v_current_stops;
	float v_speed;
	int v_capacity <- BUS_NORMAL_CAPACITY;
	list<MStop> v_next_stops;
	point v_next_loc;
	point v_current_loc;
	float v_stop_wait_time <- -1.0;
	bool v_in_city <- true;
	bool v_at_terminus <- false;
	
	list<Individual> v_passengers <- [];
	map<MStop,int> v_time_table <- [];
		
	//---------------------------------------//
	action init_vehicle (MLine mline, int direc) {
		v_line <- mline;
		v_current_direction <- direc;	
		if v_current_direction = DIRECTION_OUTGOING {
			location <- v_line.line_outgoing_locations[0];
			if v_line.line_type = LINE_TYPE_TAXI {
				// current stops for taxis may be several having all the same location
				v_current_stops <- (v_line.line_outgoing_stops.pairs where (each.value = location)) collect each.key;
			} else {
				v_current_stops <- [v_line.line_outgoing_stops.keys[0]];
			}
		} else {
			location <- v_line.line_return_locations[0];
			if v_line.line_type = LINE_TYPE_TAXI {
				v_current_stops <- (v_line.line_return_stops.pairs where (each.value = location)) collect each.key;
			} else {
				v_current_stops <- [v_line.line_return_stops.keys[0]];
			}
			
		}
		v_next_stops <- v_current_stops;
		v_next_loc <- location;
	}
	
	//---------------------------------------//
	reflex drive {
		// if the vehicle has to wait
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
			v_current_stops <- v_next_stops;
			v_current_loc <- v_next_loc;
			
			//#####################//
			if v_line.line_type != LINE_TYPE_TAXI {
				// compute timetables with theoretical speed or commercial speed ? consider real dynamic traffic ?? TODO
				// first outgoing stop : filling timetable of outgoing
				// second condition to prevent null when last outgoing stop = first return stop
				if first(v_current_stops) = first(v_line.line_outgoing_stops.keys) and v_current_direction = DIRECTION_OUTGOING {
					v_time_table <- [v_line.line_outgoing_stops.keys[0]::int(time)];
					loop i from: 1 to: length(v_line.line_outgoing_stops.keys)-1 {
						v_time_table <+ v_line.line_outgoing_stops.keys[i] :: v_time_table at v_line.line_outgoing_stops.keys[i-1] +
									(v_line.line_outgoing_dists[i-1] / v_speed) + v_stop_wait_time;
					}
				}
				// first return stop : filling timetable of return 
				else if first(v_current_stops) = first(v_line.line_return_stops.keys) and v_current_direction = DIRECTION_RETURN {
					v_time_table <- [v_line.line_return_stops.keys[0]::int(time)];
					loop i from: 1 to: length(v_line.line_return_stops.keys)-1 {
						v_time_table <+ v_line.line_return_stops.keys[i] :: v_time_table at v_line.line_return_stops.keys[i-1] +
									(v_line.line_return_dists[i-1] / v_speed) + v_stop_wait_time;
					}
				}
			}
			//#####################//
			
			if v_in_city {
				/****************************** DROP ******************************/
				// drop off all passengers who have arrived to their destination
				int droppers <- 0; int transfers <- 0;
				ask v_passengers where (each.ind_current_trip.trip_end_stop in v_current_stops) { 
					list<int> my_ind_times; // for STATS only
					
					if ind_trip_options at ind_current_trip != TRIP_FIRST {	// the passenger has arrived
						ind_times[ind_current_trip_index] <+ int(time); // final arrival time
						ind_arrived <- true;
						ind_moving <- false;
						droppers <- droppers + 1;
						ind_current_trip.trip_end_stop.stop_arrived_people <+ self;
						
						int walked_dist <- ind_used_trips at ind_current_trip;
						if myself.v_line.line_type = LINE_TYPE_TAXI {
							walked_dist <- myself.v_current_direction = DIRECTION_OUTGOING ?
									int(ind_destin_stop distance_to (myself.v_line.line_outgoing_stops at ind_destin_stop)) :
									int(ind_destin_stop distance_to (myself.v_line.line_return_stops at ind_destin_stop));
						} else {
							if ind_current_trip.trip_end_stop != ind_destin_stop {
								walked_dist <- walked_dist + int(ind_destin_stop distance_to ind_current_trip.trip_end_stop);
							}	
						}
						put walked_dist at: ind_current_trip in: ind_used_trips;
						
						// take the last list
						my_ind_times <- last(ind_times);
						
						if save_data_on {
							int z1; int z2;
							if !empty(ind_used_trips) {
								loop i from: 0 to: length(ind_used_trips) - 1 {
									MTrip mtp <- ind_used_trips.keys[i];
									z1 <- mtp.trip_start_stop.stop_zone != nil ? mtp.trip_start_stop.stop_zone.zone_code : -1;
									z2 <- mtp.trip_end_stop.stop_zone != nil ? mtp.trip_end_stop.stop_zone.zone_code : -1;
									save '' + cycle + ',' + ind_id + ',' + mtp.trip_start_stop.stop_id + ',' + mtp.trip_end_stop.stop_id
										+ ',' + z1 + ',' + z2 + ',' + ind_trip_options at mtp + ',' + mtp.trip_line.line_type + ','
										+ mtp.trip_line.line_name + ',' + mtp.trip_line_direction + ',' + mtp.trip_ride_distance + ','
										+ ind_used_trips at mtp + ',' + ind_times[i][0] + ',' + ind_times[i][1] + ',' + ind_times[i][2]
									format: "text" rewrite: false to: "../results/data_"+sim_id+"/completedtrips.csv";		
								}	
							}	
						}
					}
					else { // the passenger is making a connection (transfer)
						ind_times[ind_current_trip_index] <+ int(time); // arrival time for first trip
						ind_waiting_stop <- ind_current_trip.trip_end_stop;
						ind_waiting_stop.stop_waiting_people <+ self;
						ind_current_trip_index <- ind_current_trip_index + 1;
						ind_times <+ [int(time)]; // starting waiting time for the second trip
						transfers <- transfers + 1;
						ind_current_trip.trip_end_stop.stop_transited_people <+ self;
						// take the first list
						my_ind_times <- first(ind_times);
					}
					myself.v_passengers >- self;					
					myself.v_stop_wait_time <- myself.v_stop_wait_time + V_TIME_DROP_IND;
					
					/****************************************/	
					/**************** STATS ****************/
					if ind_current_trip.trip_line.line_type = LINE_TYPE_BUS {
						number_of_completed_bus_trips <- number_of_completed_bus_trips + 1;
						wtimes_completed_bus_trips <+ my_ind_times[1] - my_ind_times[0];
						triptimes_completed_bus_trips <+ my_ind_times[2] - my_ind_times[1];
					} else if ind_current_trip.trip_line.line_type = LINE_TYPE_BRT {
						number_of_completed_brt_trips <- number_of_completed_brt_trips + 1;
						wtimes_completed_brt_trips <+ my_ind_times[1] - my_ind_times[0];
						triptimes_completed_brt_trips <+ my_ind_times[2] - my_ind_times[1];
					} else {
						number_of_completed_taxi_trips <- number_of_completed_taxi_trips + 1;
						wtimes_completed_taxi_trips <+ my_ind_times[1] - my_ind_times[0];
						triptimes_completed_taxi_trips <+ my_ind_times[2] - my_ind_times[1];
					}
					/****************************************/	
					/***************************************/					
				}
				if (droppers + transfers) > 0 {
					write world.formatted_time() + v_line.line_name  + ' (' + v_current_direction + ') is dropping '
									+ (droppers + transfers) + ' people at ' + v_current_stops collect each.stop_name color: #blue;
					if transfers > 0 {
						write '  -> Among them, ' + transfers + " are connecting" color: #darkblue;
					}
					write '  -> ' + length(v_passengers) + " people are on board" color: #darkorange;
				}
				
				/****************************** TAKE ******************************/
				// take the maximum number of passengers
				int n_individs <- v_capacity - length(v_passengers);
				if n_individs > 0 {
					list<MStop> relevant_stops <- v_line.line_type = LINE_TYPE_TAXI ? v_current_stops :
														first(v_current_stops).stop_neighbors;
					list<Individual> waiting_individuals <- relevant_stops accumulate each.stop_waiting_people where (
										!empty(each.ind_trip_options.keys where (each.trip_line = self.v_line
											and each.trip_line_direction = self.v_current_direction
												and each.trip_start_stop in relevant_stops)));
					// if the individual is waiting at the next stop, don't take it
					waiting_individuals <- waiting_individuals where (((v_line.next_stop_location(v_current_direction, v_current_loc) = nil)
											or each.ind_waiting_stop distance_to v_current_loc <
										each.ind_waiting_stop distance_to v_line.next_stop_location(v_current_direction, v_current_loc)));
					
					if !empty(waiting_individuals) {
						//#######################################################################//
						//############ filter individuals based on active strategies ############//
						//#######################################################################//
						
						//############################## transfer ##############################/			
						// if transfer is off, remove individuals with double-trip that can still wait for a single-trip
						if !transfer_on and v_line.line_type != LINE_TYPE_TAXI {
							// first, retrieve individuals with no single trips on this vehicle (the vehicle can only transfer them)
							list<Individual> inds_to_remove <- waiting_individuals where (each.ind_current_trip_index = 0
													and empty(each.ind_trip_options.pairs where (each.value = TRIP_SINGLE
																and each.key.trip_line = v_line
																and each.key.trip_line_direction = v_current_direction
																and each.key.trip_start_stop in first(v_current_stops).stop_neighbors)));
							// see if these individuals can do a single-trip on another bus
							if !empty(inds_to_remove) {
								// individuals with a single trip on other vehicles and who can still wait for a single trip
								inds_to_remove <- (inds_to_remove where (int(time - each.ind_times[0][0]) < IND_WAITING_TIME_FOR_SINGLE_TRIPS
												and !empty(each.ind_trip_options.pairs where (each.value = TRIP_SINGLE
															and each.key.trip_line != v_line
															and each.key.trip_start_stop in first(v_current_stops).stop_neighbors))));
								// remove
								waiting_individuals <- waiting_individuals - inds_to_remove;
								if !empty(inds_to_remove) {
									write "##### " + inds_to_remove + " removed by TRANSFER form: " + self + " at: " + first(v_current_stops);
								}
							}
						}

						//############################## timetables ##############################/
						if time_tables_on and v_line.line_type != LINE_TYPE_TAXI {
							list<Individual> inds_to_remove <- [];
							
							loop indiv over: waiting_individuals {
								MTrip besttrip <- nil;
								int besttrip_type;
								//int mycorresps <- 0;
								// can this bus take the individual to his destination ?
								// first consider only trips that arrive to final destination (SINGLE or SECOND trips) 
								map<MTrip,int> mtrips <- map(indiv.ind_trip_options.pairs where (each.key.trip_line = v_line
												and each.key.trip_line_direction = v_current_direction
												and each.key.trip_start_stop in first(v_current_stops).stop_neighbors
												and (    (indiv.ind_current_trip_index = 0 and each.value = TRIP_SINGLE)
											 		  or (indiv.ind_current_trip_index = 1 and each.value = TRIP_SECOND))));
								if !empty(mtrips) {
									// time to arrive to final destination using this bus
									pair<MTrip,int> ppr <- mtrips.pairs where (each.key.trip_end_stop in v_time_table.keys)
																		with_min_of (v_time_table at each.key.trip_end_stop);
									besttrip <- ppr != nil ? ppr.key : nil;
								}// else {
									// if no SINGLE or SECOND trips are found, then maybe a FIRST
									/*if indiv.ind_current_trip_index = 0 {
										mtrips <- map(indiv.ind_trip_options.pairs where (each.key.trip_line = v_line
											and each.key.trip_line_direction = v_current_direction and each.value = TRIP_FIRST
											and each.key.trip_start_stop in first(v_current_stops).stop_neighbors));
										
										// then find time to arrive to the best correspondance through FIRST trips
										list res <- world.best_correspondance(mtrips.pairs where
												(each.value = TRIP_FIRST /*and each.key.trip_end_stop in v_time_table.keys*//*) collect each.key,
												indiv.ind_trip_options.pairs where (each.value = TRIP_SECOND) collect each.key);
										besttrip <- MTrip(res[0]);
										mycorresps <- int(res[1]);
									}*/
								//}
								//
								if besttrip != nil {
									besttrip_type <- mtrips at besttrip;
									int time_to_dest_this <- v_time_table at besttrip.trip_end_stop;
									// theoretical arrival time not reached yet
									if time_to_dest_this > v_time_table at first(v_current_stops) {
										// trips using other lines
										map<MTrip,int> othertrips <- [];
										// get trip types according to the best trip type
										if besttrip_type != TRIP_FIRST {
											// if the best trip on this bus takes to destination, compare only with trips that take to destination
											othertrips <- map(indiv.ind_trip_options.pairs where (each.key.trip_line != v_line
														and each.key.trip_start_stop in first(v_current_stops).stop_neighbors
													and (    (indiv.ind_current_trip_index = 0 and each.value = TRIP_SINGLE)
										 		  		  or (indiv.ind_current_trip_index = 1 and each.value = TRIP_SECOND))));
										} else {
											// if the best trip on this bus takes to a correspondance, compare with all
										//	othertrips <- map(indiv.ind_trip_options.pairs where (each.key.trip_line != v_line and
											//	/*each.value = TRIP_FIRST and*/ each.key.trip_start_stop in first(v_current_stops).stop_neighbors));
										}
										loop mtrp over: othertrips.keys {
											int min_time_to_dest_others <- #max_int;
											// vehicles that can serve this trip
											list<MVehicle> vehs <- BusVehicle where (each.v_line = mtrp.trip_line
																and each.v_current_direction = mtrp.trip_line_direction and 
																!empty(each.v_time_table) and mtrp.trip_end_stop in each.v_time_table.keys)
															+
																BRTVehicle where (each.v_line = mtrp.trip_line
																and each.v_current_direction = mtrp.trip_line_direction and 
																!empty(each.v_time_table) and mtrp.trip_end_stop in each.v_time_table.keys);
											
											if !empty(vehs) {
												// only vehicles which did not reach the current stop yet
												if mtrp.trip_line_direction = DIRECTION_OUTGOING {
													vehs <- vehs where (each.v_line.line_outgoing_stops index_of first(each.v_current_stops) < 
																each.v_line.line_outgoing_stops index_of mtrp.trip_start_stop);
												} else {
													vehs <- vehs where (each.v_line.line_return_stops index_of first(each.v_current_stops) < 
																each.v_line.line_return_stops index_of mtrp.trip_start_stop);
												}
												
												if !empty(vehs) {
													MVehicle veh <- vehs with_min_of (each.v_time_table at mtrp.trip_end_stop);
													int ttm <- veh.v_time_table at mtrp.trip_end_stop;
													
													if (ttm > veh.v_time_table at first(v_current_stops)) and ttm < min_time_to_dest_others {
														/*if othertrips at mtrp = TRIP_FIRST {
															list<MTrip> myseconds <- indiv.ind_trip_options.pairs where (each.value = TRIP_SECOND
																				and each.key.trip_start_stop in mtrp.trip_end_stop.stop_neighbors)
																					collect each.key;
															if !empty(myseconds) {
																int ncorr <- length(remove_duplicates(myseconds collect (each.trip_line)));
																if ncorr > mycorresps {
																	min_time_to_dest_others <- ttm;
																}	
															}
														} else {*/
															min_time_to_dest_others <- ttm;
														//}
													}
												}
											}
											if min_time_to_dest_others < time_to_dest_this {
												write "##### " + indiv + " removed by TIMETABLES form: " + self + " at: " + first(v_current_stops);
												inds_to_remove <+ indiv;
												break;
											}
										}											
									}
								}
							}
							waiting_individuals <- waiting_individuals - inds_to_remove;
						}
						
						//#######################################################################//
						
						int takens <- 0;
						ask n_individs among waiting_individuals {
							if ind_waiting_stop.stop_waiting_people contains self { //prevent multiple vahicles taking the same individual at the same time
								ind_waiting_stop.stop_waiting_people >- self;
								takens <- takens + 1;
								myself.v_passengers <+ self;
								myself.v_stop_wait_time <- myself.v_stop_wait_time + V_TIME_TAKE_IND;
								
								relevant_stops <- myself.v_line.line_type = LINE_TYPE_TAXI ? myself.v_current_stops :
															first(myself.v_current_stops).stop_neighbors;
								ind_current_trip <- (ind_trip_options.keys where (each.trip_line = myself.v_line
															and each.trip_line_direction = myself.v_current_direction
															and each.trip_start_stop in relevant_stops))
													with_min_of (each.trip_ride_distance);
								
								ind_times[ind_current_trip_index] <+ int(time); // end of waiting time, board time
								// walking distance
								int walked_dist <- 0;
								if myself.v_line.line_type = LINE_TYPE_TAXI {
									walked_dist <- myself.v_current_direction = DIRECTION_OUTGOING ?
											int(ind_waiting_stop distance_to (myself.v_line.line_outgoing_stops at ind_waiting_stop)) :
											int(ind_waiting_stop distance_to (myself.v_line.line_return_stops at ind_waiting_stop));
								} else {
									if ind_current_trip.trip_start_stop != ind_waiting_stop {
										walked_dist <- int(ind_waiting_stop distance_to ind_current_trip.trip_start_stop);
									}	
								}
								ind_used_trips <+ ind_current_trip::walked_dist;
							}



						}	
						if takens > 0 {
							write world.formatted_time() + v_line.line_name  + ' (' + v_current_direction + ') is taking '
								+ takens + ' people at ' + v_current_stops collect each.stop_name color: #darkgreen;
							write '  -> Passengers : ' + length(v_passengers) + " people are on board" color: #darkorange;
						}	
					}
				}
			}
			
			// to know the next stop
			if v_current_direction = DIRECTION_OUTGOING { // outgoing
				if v_current_stops contains last(v_line.line_outgoing_stops.keys) and !v_at_terminus { // last outgoing stop
					v_next_loc <- v_line.line_return_locations[0];
					v_next_stops <- (v_line.line_return_stops.pairs where (each.value = v_next_loc)) collect each.key;
					v_at_terminus <- true;
				} else {
					if v_current_stops contains first(v_line.line_return_stops.keys) {
						v_current_direction <- DIRECTION_RETURN;
						v_at_terminus <- false;
					} else {
						v_next_loc <- v_line.line_outgoing_locations[(v_line.line_outgoing_locations index_of v_current_loc) +1];
						v_next_stops <- (v_line.line_outgoing_stops.pairs where (each.value = v_next_loc)) collect each.key;
					}
				}
			} else { // return
				if v_current_stops contains last(v_line.line_return_stops.keys) and !v_at_terminus { // last return stop
					v_next_loc <- v_line.line_outgoing_locations[0];
					v_next_stops <- (v_line.line_outgoing_stops.pairs where (each.value = v_next_loc)) collect each.key;
					v_at_terminus <- true; // useful when the last outgoing stop is the same as first return
				} else {
					if v_current_stops contains first(v_line.line_outgoing_stops.keys) {
						v_current_direction <- DIRECTION_OUTGOING;
						v_at_terminus <- false;
					} else {
						v_next_loc <- v_line.line_return_locations[(v_line.line_return_locations index_of v_current_loc) +1];
						v_next_stops <- (v_line.line_return_stops.pairs where (each.value = v_next_loc)) collect each.key;	
					}
				}
			}
			if !(v_line.line_type = LINE_TYPE_TAXI and v_stop_wait_time = 0) {
				return;	
			}
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
	float v_speed <- traffic_on ? TAXI_TRAFFIC_SPEED : TAXI_FREE_SPEED;
	int v_capacity <- TAXI_CAPACITY;
	
	image_file v_icon <- image_file("../../includes/img/taxi.png");
	geometry shape <- envelope(v_icon);
	
	aspect default {
		draw v_icon size: {100#meter,50#meter} rotate: heading;
	}
}

/*** end of species definition ***/
