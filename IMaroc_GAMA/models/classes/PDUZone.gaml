/**
* Name: PDUZone
* Description: defines the PDUZone species and its related constantes, variables, and methods.
* 				A PDUZone agent represents one entity of the PDU (Plan de déplacements urbains) 2009 division.
* Authors: Laatabi
* For the i-Maroc project.
*/

model PDUZone

import "MStop.gaml"

global {
	// city area
	geometry city_area;
	
		// simulation starts at 06:00 morning
	float SIM_START_HOUR <- 6#hour;
	
	// format the current time to a printable format [hh:mm:ss]
	string formatted_time { 
		int tt <- int(SIM_START_HOUR) + int(time);
		return "[" + get_time_frag(tt, 1) + ":" + get_time_frag(tt, 2) + ":" + get_time_frag(tt, 3) + "] ";
	}
	
	// returns one fragment of a given time 
	string get_time_frag (int tt, int frag) {
		if frag = 1 { // hours
			return zero_time(int(tt / 3600));
		} else if frag = 2 { // minutes
			return zero_time(int((tt mod 3600) / 60));
		} else { // seconds
			return zero_time((tt mod 3600) mod 60);
		}
	}
	
	// adds a zero if it is only one digit (8 --> 08)
	string zero_time (int i) {
		return (i <= 9 ? "0" : "") + i;
	}	
}

/*******************************/
/******* PDUZone Species ******/
/*****************************/

species PDUZone schedules: [] parallel: true {
	int pduz_code;
	string pduz_name;
	
	aspect default {
		draw shape color: #whitesmoke border: #black;
	}
}

/*** end of species definition ***/