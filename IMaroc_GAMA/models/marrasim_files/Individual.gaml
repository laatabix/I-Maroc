/**
* Name: Individual
* Description: defines the Individual species and its related constantes, variables, and methods.
* 				An Individual agent represents one person that travel using the public network between
* 				an origin and a destination.
* Authors: Laatabi, Benchra
* For the i-Maroc project. 
*/

model Individual

import "MTrip.gaml"

global {
	
}

/*******************************/
/***** Individual Species *****/
/*****************************/

species Individual parallel: true {
	int ind_id;
	PDUZone ind_origin_zone;
	PDUZone ind_destin_zone;
	MStop ind_origin_stop;
	MStop ind_destin_stop;
	MStop ind_waiting_stop;
	
	list<list<int>> ind_times;
	bool ind_moving <- false;
	bool ind_arrived <- false;
	
	MTrip ind_current_trip;
	int ind_current_trip_index <- 0; // whether the individual is in his first or second trip
	map<MTrip,int> ind_trip_options <- []; // MTrip::Trip Type (Single, First, Second)
	map<MTrip,int> ind_used_trips <- []; // MTrip::Walk Distance to take this trip
	
	
	MTrip add_trip (MStop stop1, MStop stop2, MLine li, int dir) {
		MTrip mtp <- MTrip first_with (each.trip_start_stop = stop1 and each.trip_end_stop = stop2 and
										each.trip_line = li and each.trip_line_direction = dir);
		if mtp = nil {
			create MTrip returns: mytrip {
				self.trip_start_stop <- stop1;
				self.trip_end_stop <- stop2;
				self.trip_line <- li;
				self.trip_line_direction <- dir;
				
				graph mygraph <- li.line_outgoing_graph;
				
				if li.line_type = LINE_TYPE_TAXI {
					if dir = DIRECTION_RETURN {
						mygraph <- li.line_return_graph;
					}
					self.trip_ride_distance <- int(path_between(mygraph, stop1.stop_connected_taxi_lines at (TaxiLine(li)::dir),
															stop2.stop_connected_taxi_lines at (TaxiLine(li)::dir)).shape.perimeter);
				} else {
					map<MStop,point> mystops <- li.line_outgoing_stops;
					if dir = DIRECTION_RETURN {
						mystops <- li.line_return_stops;
						mygraph <- li.line_return_graph;
					}
					self.trip_ride_distance <- int(path_between(mygraph, mystops at stop1, mystops at stop2).shape.perimeter);
				}
			}
			return mytrip[0];
		} else {
			return mtp;
		}
	}
	
	
	action find_trip_options {
		list<MStop> mstops1 <-  [];
		list<MStop> mstops2 <-  [];
		MStop stop1;
		MStop stop2;
		int direc1;
		int direc2;
		
		list<pair<MLine,int>> single_lines <- [];
		
		//----------------------------- single (one line trips)
        loop single_line over: (remove_duplicates(ind_origin_stop.stop_neighbors accumulate each.stop_lines) +
        					remove_duplicates(ind_origin_stop.stop_connected_taxi_lines.keys))
        				inter
        					(remove_duplicates(ind_destin_stop.stop_neighbors accumulate each.stop_lines) + 
        						remove_duplicates(ind_destin_stop.stop_connected_taxi_lines.keys)) {
        	
        	if single_line.key.line_type = LINE_TYPE_TAXI {
        		stop1 <- ind_origin_stop;
        		stop2 <- ind_destin_stop;
        	} else {
	        	mstops1 <- single_line.value = DIRECTION_OUTGOING ? single_line.key.line_outgoing_stops.keys :
	        														single_line.key.line_return_stops.keys;
	        	stop1 <- mstops1 contains ind_origin_stop ? ind_origin_stop : mstops1 closest_to ind_origin_stop;
	        	stop2 <- mstops1 contains ind_destin_stop ? ind_destin_stop : mstops1 closest_to ind_destin_stop;
	        }
        	direc1 <- single_line.key.can_link_stops(stop1, stop2);
    		if direc1 != -1 {
    			ind_trip_options <+ add_trip(stop1, stop2, single_line.key, direc1)::TRIP_SINGLE;
    			single_lines <+ single_line;
    		}
        }
        
		//----------------------------- double (two lines trips)
		list<pair<MLine,int>> omit_lines <- [];
        loop first_line over: (remove_duplicates(ind_origin_stop.stop_neighbors accumulate each.stop_lines) +
        	 					remove_duplicates(ind_origin_stop.stop_connected_taxi_lines.keys)) - single_lines {
        	omit_lines <- single_lines + [(first_line.key::DIRECTION_OUTGOING),(first_line.key::DIRECTION_RETURN)];

        	if first_line.key.line_type = LINE_TYPE_TAXI {
        		stop1 <- ind_origin_stop;
        		mstops1 <- first_line.value = DIRECTION_OUTGOING ? TaxiLine(first_line.key).tl_connected_stops_outgoing :
        												TaxiLine(first_line.key).tl_connected_stops_return;
        		mstops1 <- (copy_between(mstops1, (mstops1 index_of stop1)+1, length(mstops1)) - stop1.stop_neighbors);
        	} else {
        		mstops1 <- first_line.value = DIRECTION_OUTGOING ? first_line.key.line_outgoing_stops.keys :
        														first_line.key.line_return_stops.keys;
        		stop1 <- mstops1 contains ind_origin_stop ? ind_origin_stop : mstops1 closest_to ind_origin_stop;
        		// only stops that come after the considered stop and are in neighbors
        		mstops1 <- (copy_between(mstops1, (mstops1 index_of stop1)+1, length(mstops1)) - stop1.stop_neighbors);
           	}
           	
            loop second_line over: (remove_duplicates(ind_destin_stop.stop_neighbors accumulate each.stop_lines) +
            						remove_duplicates(ind_destin_stop.stop_connected_taxi_lines.keys)) - omit_lines {

            	if second_line.key.line_type = LINE_TYPE_TAXI {
        			mstops2 <- second_line.value = DIRECTION_OUTGOING ? TaxiLine(second_line.key).tl_connected_stops_outgoing :
        												TaxiLine(second_line.key).tl_connected_stops_return;
        			stop2 <- ind_destin_stop;
        		} else {
        			mstops2 <- second_line.value = DIRECTION_OUTGOING ? second_line.key.line_outgoing_stops.keys :
            														second_line.key.line_return_stops.keys;
	            	stop2 <- mstops2 contains ind_destin_stop ? ind_destin_stop : mstops2 closest_to ind_destin_stop;
				}
				mstops2 <- (copy_between(mstops2, 0, (mstops2 index_of stop2)+1) - stop2.stop_neighbors);
				
				if !empty(remove_duplicates(mstops1 accumulate (each.stop_neighbors)) inter mstops2) {
					list<MStop> inter_stops <- world.first_intersecting_stops(mstops1, mstops2);
					
					// get the best connection (closest pair of stops to each other)
					list<MStop> clos_stops <- world.closest_stops (mstops1 inter inter_stops, mstops2 inter inter_stops);
					
					if !empty(clos_stops) {
						direc1 <- first_line.key.can_link_stops(stop1, first(clos_stops));
				 		direc2 <- second_line.key.can_link_stops(last(clos_stops), stop2);
						if direc1 != -1 and direc2 != -1 {
				 			ind_trip_options <+ add_trip(stop1, first(clos_stops), first_line.key, direc1)::TRIP_FIRST;
				 			ind_trip_options <+ add_trip(last(clos_stops), stop2, second_line.key, direc2)::TRIP_SECOND;
				 		}
				 	}	
				 }
            }
        }
    }
}

/*** end of species definition ***/