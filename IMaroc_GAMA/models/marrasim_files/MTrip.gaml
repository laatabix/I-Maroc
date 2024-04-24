/**
* Name: MTrip
* Description: defines the MTrip species and its related constantes, variables, and methods.
* 				A MTrip agent represents one journey from a start point to a destination.
* Authors: Laatabi, Benchra
* For the i-Maroc project.
*/

model MTrip

import "MStop.gaml"

global {
	
	int TRIP_SINGLE <- 1;
	int TRIP_FIRST 	<- 2;
	int TRIP_SECOND <- 3;

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