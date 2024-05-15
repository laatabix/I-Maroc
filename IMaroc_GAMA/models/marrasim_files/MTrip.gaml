/**
* Name: MTrip
* Description: defines the MTrip species and its related constantes, variables, and methods.
* 				A MTrip agent represents one journey from a start point to a destination.
* Authors: Laatabi
* For the i-Maroc project.
*/

model MTrip

import "MStop.gaml"

global {
	
	int TRIP_SINGLE <- 1;
	int TRIP_FIRST 	<- 2;
	int TRIP_SECOND <- 3;
	
	
	// best correspondance between two list of FIRST and SECOND trips
	// the best correspondance is where there are more possible correspondances with different lines ? //TODO
	list best_correspondance (list<MTrip> firsts, list<MTrip> seconds){
		int max_corr <- 0;
		int n_corr <- 0;
		MTrip best_trip <- nil;

		loop trip1 over: firsts sort_by each.trip_ride_distance {
			list<MTrip> mysecs <- seconds where (trip1.trip_end_stop in each.trip_start_stop.stop_neighbors);
			if !empty(mysecs) {
				n_corr <- length(remove_duplicates(mysecs collect (each.trip_line)));
				if n_corr > max_corr {
					max_corr <- n_corr;
					best_trip <- trip1;
				}
			}
		}
		return [best_trip,max_corr];
	}

}

/*******************************/
/******** MTrip Species *******/
/*****************************/

species MTrip schedules: [] {
	
	int trip_id;
	MStop trip_start_stop;
	MStop trip_end_stop;
	
	MLine trip_line;
	int trip_line_direction;
	
	int trip_ride_distance <- 0;
}


/*** end of species definition ***/