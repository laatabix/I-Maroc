/**
* Name: MStop
* Description: defines the MStop species and its related constantes, variables, and methods.
* 				A MStop agent represents a location where buses can take or drop off people.
* Authors: Laatabi
* For the i-Maroc project.
*/

model MStop

import "MLine.gaml"
import "PDUZone.gaml"
import "Individual.gaml"

global {
	float STOP_NEIGHBORING_DISTANCE <- 400#m;
	
	list<MStop> first_intersecting_stops (list<MStop> li1, list<MStop> li2) {
		if empty(li1) or empty(li2) {
			return [];
		}
		list<MStop> lisa <- [];
		bool sstop <- false;
		loop elem1 over: li1 {
			list<MStop> inters <- elem1.stop_neighbors inter li2;
			if !empty(inters) {
				if length(inters) = 1 and first(inters) = elem1{
					lisa <<+ elem1.stop_neighbors;
				} else {
					lisa <<+ elem1.stop_neighbors inter (li2 closest_to elem1).stop_neighbors;
				}
				sstop <- true;
			}
			if sstop {
				break;
			}
		}
		return remove_duplicates(lisa);
	}
	
	list<MStop> closest_stops (list<MStop> li1, list<MStop> li2) {
		if empty(li1) or empty(li2) {
			return [];
		}
		
		MStop stop1;
		MStop stop2;
		MStop clos;
		float min_dist <- #max_float;
		float ddst;
		loop stp over: li1 {
			if li2 contains stp {
				clos <- stp;
				ddst <- 0.0;
			} else {
				clos <- li2 closest_to stp;
				ddst <- stp distance_to clos;
			}
			if ddst < min_dist {
				min_dist <- ddst;
				stop1 <- stp;
				stop2 <- clos;
			}
		}
		return [stop1,stop2];
	}
}

/*******************************/
/******* BusStop Species ******/
/*****************************/

species MStop schedules: [] parallel: true {
	int stop_id;
	string stop_name;
	PDUZone stop_zone;
	
	list<Individual> stop_waiting_people <- [];
	list<Individual> stop_transited_people <- [];
	list<Individual> stop_arrived_people <- [];
	list<MStop> stop_neighbors <- [];
	// list of line/direction that pass by the stop
	list<pair<MLine,int>> stop_lines <- [];
	// for each stop, the taxi lines (+direction) that an Individual can take + closest line on the taxiline to the stop
	list<pair<TaxiLine,int>> stop_connected_taxi_lines <- [];
	//map<MLine,float> stop_last_vehicle_depart_time <-[];
}

species BusStop parent: MStop {
	geometry shape <- circle(40#meter);
	aspect default {
		draw circle(40#meter) color: #gamablue;
		draw circle(20#meter) color: #white;		
	}
}

species BRTStop parent: MStop {
	geometry shape <- circle(40#meter);
	aspect default {
		draw circle(40#meter) color: #darkred;
		draw circle(20#meter) color: #white;
	}
}

species TaxiStop parent: MStop{
	geometry shape <- circle(40#meter);
	aspect default {
		draw circle(40#meter) color: #darkorange;
		draw circle(20#meter) color: #white;
	}
}


/*** end of species definition ***/