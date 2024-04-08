/**
* Name: Individual
* Description: defines the Individual species and its related constantes, variables, and methods.
* 				An Individual agent represents one person that travel using the public network between
* 				an origin and a destination.
* Authors: Laatabi, Benchra
* For the i-Maroc project. 
*/

model Individual

import "PDUZone.gaml"

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
}

/*** end of species definition ***/