/**
* Name: BusStop
* Description: defines the BusStop species and its related constantes, variables, and methods.
* 				A BusStop agent represents a location where buses can take or drop off people.
* Authors: Laatabi
* For the i-Maroc project.
*/

model MStop

import "MLine.gaml"
import "PDUZone.gaml"

global {
	
}

/*******************************/
/******* BusStop Species ******/
/*****************************/

species MStop schedules: [] parallel: true {
	int stop_id;
	string stop_name;
	PDUZone stop_zone;
}	

species BusStop parent: MStop{
	aspect default {
		draw circle(30#meter) color: #gamablue;
		draw circle(20#meter) color: #white;
		
	}
}

species BRTStop parent: MStop{
	aspect default {
		draw circle(30#meter) color: #darkred;
		draw circle(20#meter) color: #white;
	}
}

species TaxiStop parent: MStop{
	aspect default {
		draw circle(30#meter) color: #yellowgreen;
		draw circle(20#meter) color: #white;
	}
}


/*** end of species definition ***/