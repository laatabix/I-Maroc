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
	
	// level colors
	list<rgb> level_colors <- [#white,#yellow,#orange,#red,#darkred];
	
	// city area
	//geometry city_area;
	
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
	
	/****************************************************************************/
	/****************************************************************************/
	// update colors 
	action update_zones_colors {
		// compute indicators
		map<PDUZone,int> waiting_people <- [];
		map<PDUZone,int> waiting_times <- [];
		map<PDUZone,int> trip_times <- [];
		map<PDUZone,int> bus_delays <- [];
		ask PDUZone {
			waiting_people <+ self::zone_stops sum_of (length(each.stop_waiting_people));
			waiting_times <+ self::mean(zone_stops accumulate ((each.stop_waiting_people) accumulate int(time - last(each.ind_times)[0])));
			trip_times <+ self::mean(
				zone_stops accumulate ((each.stop_arrived_people) accumulate (last(each.ind_times)[2] - last(each.ind_times)[1])) +
				zone_stops accumulate ((each.stop_transited_people) accumulate (first(each.ind_times)[2] - first(each.ind_times)[1])));
		}
		
		// set colors
		float interval_wpeople <- max(waiting_people)/length(level_colors);
		float interval_wtimes <- max(waiting_times)/length(level_colors);
		float interval_ttimes <- max(trip_times)/length(level_colors);
		ask PDUZone {
			wp_color <- interval_wpeople = 0 ? #lightgray : level_colors[min([4,int(waiting_people at self / interval_wpeople)])];
			wt_color <- interval_wtimes = 0 ? #lightgray : level_colors[min([4,int(waiting_times at self / interval_wtimes)])];
			tt_color <- interval_ttimes = 0 ? #lightgray : level_colors[min([4,int(trip_times at self / interval_ttimes)])];
		}
	}
}

/*******************************/
/******* PDUZone Species ******/
/*****************************/

species PDUZone schedules: [] parallel: true {
	int zone_code;
	string zone_name;
	list<MStop> zone_stops <- [];
	
	rgb wp_color <- #lightgray;
	rgb wt_color <- #lightgray;
	rgb tt_color <- #lightgray;
	rgb bd_color <- #lightgray;
	
	aspect default {
		draw shape color: #black border: #white;
	}
	
	aspect wait_people {
		draw shape color: wp_color border: #black;
	}
	aspect wait_time {
		draw shape color: wt_color border: #black;
	}
	aspect trip_time {
		draw shape color: tt_color border: #black;
	}
	aspect bus_delay {
		draw shape color: #whitesmoke border: #black;
	}
}

/*** end of species definition ***/