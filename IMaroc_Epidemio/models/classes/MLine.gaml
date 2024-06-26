/**
* Name: BusLine
* Description: defines the BusLine species and its related constantes, variables, and methods.
* 				A BusLine agent represents an outgoing-return path of a bus.
* Authors: Laatabi
* For the i-Maroc project.
*/

model MLine

import "MVehicle.gaml"
import "MStop.gaml"

global {
	
	int DIRECTION_OUTGOING <- 1;
	int DIRECTION_RETURN <- 2;
	// colors to color bus lines when displayed
	list<rgb> BL_COLORS <- [#darkblue,#darkcyan,#darkgoldenrod,#darkgray,#darkkhaki,#darkmagenta,#darkolivegreen,#darkorchid,
								#darksalmon,#darkseagreen,#darkslateblue,#darkslategray,#darkturquoise,#darkviolet];

	//font LFONT0 <- font("Arial", 5, #bold);
}

/*******************************/
/******* BusLine Species ******/
/*****************************/

species MLine schedules: [] parallel: true {
	int line_id;
	string line_name;
	float line_com_speed <- URBAN_SPEED; // average speed while considering the traffic constraints
	map<MStop,point> line_outgoing_stops <- []; // list of bus stops on an outgoing path
	map<MStop,point> line_return_stops <- []; // bus stops on the return path
	//rgb bl_color <- one_of(BL_COLORS);
	geometry line_outgoing_shape;	
	geometry line_return_shape;
	path line_outgoing_path;	
	path line_return_path;	

}

species BusLine parent: MLine {
	aspect default {
		draw (shape+10#meter) color: #gamablue;
		draw (shape+5#meter) color: #white;
	}	
}

species BRTLine parent: MLine {
	aspect default {
		draw (shape+10#meter) color: #darkred;
		draw (shape+5#meter) color: #white;
	}	
}

species TaxiLine parent: MLine {
	aspect default {
		draw (shape+10#meter) color: #yellowgreen;
		draw (shape+5#meter) color: #white;
	}
}

/*** end of species definition ***/
