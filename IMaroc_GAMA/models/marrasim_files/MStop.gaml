/**
* Name: MStop
* Description: defines the MStop species and its related constantes, variables, and methods.
* 				A MStop agent represents a location where buses can take or drop off people.
* Authors: Laatabi, Benchra
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
			if !empty(elem1.stop_neighbors inter li2) {
				lisa <<+ elem1.stop_neighbors;
				sstop <- true;
			} else if sstop {
				break;
			}
		}
		return remove_duplicates(lisa);
	}
	
	list<MStop> closest_stops (list<MStop> li1, list<MStop> li2) {
		if empty(li1) or empty(li2) {
			return [];
		}
		MStop stop1 <- first(li1);
		MStop stop2 <- li2 contains stop1 ? stop1 : li2 closest_to stop1;
		if stop1 != stop2 {
			stop1 <- li1 contains stop2 ? stop2 : li1 closest_to stop2;
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
	list<MStop> stop_neighbors <- [];
	// list of line/direction that pass by the stop
	list<pair<MLine,int>> stop_lines <- [];
	// for each stop, the taxi lines (+direction) that an Individual can take + closest line on the taxiline to the stop
	map<pair<TaxiLine,int>,point> stop_connected_taxi_lines <- [];
}	

species BusStop parent: MStop{
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
		draw circle(40#meter) color: #darkgreen;
		draw circle(20#meter) color: #white;
	}
}


/*** end of species definition ***/