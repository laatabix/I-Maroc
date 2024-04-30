/**
* Name: Main
* Description: this is the main file to launch the MarraSIM model.
* 			The model simulates the public transport traffic in Marrakesh.
* 			This version of the model includes the bus network, the BRT network, and the Grand Taxis network.
* 
* Authors: Laatabi, Benchra
* For the i-Maroc project. 
*/

model MarraSIM
import "marrasim_files/PDUZone.gaml"
import "marrasim_files/Individual.gaml"

global {

	// shapefiles of the model environment
	file marrakesh_pdu <- shape_file("../includes/gis/PDU_zoning/zonage_pdu.shp"); // PDU (Plan de Déplacement Urbain) zoning
	
	file marrakesh_bus_lines <- shape_file("../includes/gis/bus_network/bus_lines.shp"); // bus_lines
	file marrakesh_bus_stops <- shape_file("../includes/gis/bus_network/bus_stops.shp"); // bus stops
	
	file marrakesh_brt_lines <- shape_file("../includes/gis/BRT_network/BRT_lines.shp"); // bus_lines
	file marrakesh_brt_stops <- shape_file("../includes/gis/BRT_network/BRT_stations.shp"); // bus stops
	
	file marrakesh_taxi_lines <- shape_file("../includes/gis/taxi_network/taxi_lines.shp"); // bus_lines
	file marrakesh_taxi_stations <- shape_file("../includes/gis/taxi_network/taxi_stations.shp"); // bus stops
	
	// shape of the environment (the convex hull of regional roads shapefile)
	geometry shape <- envelope (marrakesh_bus_lines);
	
	// simulation parameters
	float step <- 10#second;// defining one simulation step as X seconds
	
	float current_affluence <- 0.0;
	list<float> hourly_affluence <- [0.000,0.000,0.000,0.000,0.000,0.000,0.05,0.050,0.100,0.100,0.050,0.050, // [00:00 -> 11:00]
								0.100,0.100,0.050,0.050,0.050,0.050,0.100,0.050,0.025,0.0125,0.0125,0.000];// [12:00 ->  23:00]
	
	/****************************************/	
	/**************** STATS ****************/
	list<list<int>> number_of_completed_trips <- [[],[],[]];
	list<list<int>> mean_wait_time_completed_trips <- [[],[],[]];
	list<list<int>> mean_trip_time_completed_trips <- [[],[],[]];
	/****************************************/	
	/***************************************/
	
	/*******************************/
	/******** Initialization ******/
	/*****************************/
	init {
		write "--+-- START OF INIT --+--" color: #green;
		
		// create the environment: city, districts, roads, traffic signals
		write "Creating the city environment ...";
		create PDUZone from: marrakesh_pdu with: [zone_code::int(get("id")), zone_name::get("label")];
		city_area <- envelope(PDUZone);
		
		/**************************************************************************************************************************/
		/*** BUS LINES ***/
		/**************************************************************************************************************************/
		// create busses, bus stops
		//*
		write "Creating bus lines and bus stops ...";
		create BusStop from: marrakesh_bus_stops with: [stop_id::int(get("ID")), stop_name::get("NAME")]{
			stop_zone <- first(PDUZone overlapping self);
		}
		if BUS_ON {
			create dummy_geom from: marrakesh_bus_lines with: [g_name::get("NAME"),g_direction::int(get("DIR"))];
			matrix busMatrix <- matrix(csv_file("../includes/gis/bus_network/bus_lines_stops.csv",true));
			
			dummy_geom bsout;
			dummy_geom bsret;
			list<point> bsoutpoints;
			list<point> bsretpoints;
			loop i from: 0 to: busMatrix.rows -1 {
				string bus_line_name <- busMatrix[0,i];
				
				if !(bus_line_name in ["L40","L41","L332","L19"]) { 
					// create the bus line if it does not exist yet
					BusLine current_bl <- first(BusLine where (each.line_name = bus_line_name));
					
					if current_bl = nil {
						bsout <- (dummy_geom first_with (each.g_name = bus_line_name and each.g_direction = DIRECTION_OUTGOING));
						bsret <- (dummy_geom first_with (each.g_name = bus_line_name and each.g_direction = DIRECTION_RETURN));
						bsoutpoints <- points_on(bsout,25#m);
						bsretpoints <- points_on(bsret,25#m);
						
						create BusLine returns: my_busline {
							do init_line (bus_line_name, bsout.shape, bsret.shape);
						}
						current_bl <- my_busline[0];
					}
					
					MStop current_bs <- BusStop first_with (each.stop_id = int(busMatrix[3,i]));
					if current_bs != nil {
						ask current_bl {
							if int(busMatrix[1,i]) = DIRECTION_OUTGOING {
								do add_stop (DIRECTION_OUTGOING,current_bs,int(busMatrix[2,i]),bsoutpoints);
							} else {
								do add_stop (DIRECTION_RETURN,current_bs,int(busMatrix[2,i]),bsretpoints);
							}
						}
					} else {
						write "Error, the stop does not exist : " + busMatrix[3,i] + " (" + busMatrix[1,i] +")" color: #red;
						return;
					}	
				}
			}
			// clean unused bus stops
			ask BusStop - remove_duplicates(BusLine accumulate (each.line_outgoing_stops.keys + each.line_return_stops.keys)) {
				do die;
			}
			ask dummy_geom { do die; }
			
			// creating n_vehicles for each bus line
			write "Creating bus vehicles ...";
			matrix busDataMatrix <- matrix(csv_file("../includes/gis/bus_network/bus_lines_data.csv",true));
			ask BusLine {
				int n_vehicles <- DEFAULT_NUMBER_BUS;
				int n_large_vehicles <- 0;
				if busDataMatrix index_of line_name != nil {
					int yindex <- int((busDataMatrix index_of line_name).y);
					n_vehicles <- int(busDataMatrix[1, yindex]);
					n_large_vehicles <- int(busDataMatrix[8, yindex]);
					line_com_speed <- float(busDataMatrix[7, yindex]) #km/#h;
					line_interval_time_m <- float(busDataMatrix[4, yindex]) #minute;
				}
				do create_vehicles (int(n_vehicles/2), DIRECTION_OUTGOING);
				do create_vehicles (int(n_vehicles/2), DIRECTION_RETURN);
				ask n_large_vehicles among BusVehicle where (each.v_line = self) {
					v_capacity <- BUS_LARGE_CAPACITY;
				}
			}	
			ask BusLine - (BusLine inside city_area) {
				sub_urban_busses <<+ BusVehicle where (each.v_line = self);
			}
			urban_busses <<+ list(BusVehicle) - urban_busses;
		}
		/**************************************************************************************************************************/
		/*** BRT LINES ***/
		/**************************************************************************************************************************/
		write "Creating BRT stops and lines ...";
		create BRTStop from: marrakesh_brt_stops with: [stop_id::int(get("ID")), stop_name::get("NAME")]{
			stop_zone <- first(PDUZone overlapping self);
			if stop_zone = nil {
				stop_zone <- PDUZone closest_to self;
			}
		}
		if BRT_ON {
			create dummy_geom from: marrakesh_brt_lines with: [g_id::int(get("ID")),g_name::get("NAME")];
			matrix brtMatrix <- matrix(csv_file("../includes/gis/BRT_network/BRT_lines_stations.csv",true));
	
			dummy_geom brtgeom;
			list<point> brtpoints;
			loop i from: 0 to: brtMatrix.rows -1 {
				int idbrt <- int(brtMatrix[0,i]);
				// create the BRT line if it does not exist yet
				BRTLine current_bl <- first(BRTLine where (each.line_id = idbrt));
				if current_bl = nil {
					brtgeom <- dummy_geom first_with (each.g_id = idbrt);
					brtpoints <- points_on(brtgeom,25#m);
					
					create BRTLine returns: my_brt {
						line_id <- idbrt;
						do init_line ("BRT"+line_id, brtgeom.shape, brtgeom.shape);
					}
					current_bl <- my_brt[0];
				}
				MStop current_bs <- BRTStop first_with (each.stop_id = int(brtMatrix[1,i]));
				if current_bs != nil {
					ask current_bl {
						do add_stop (int(brtMatrix[2,i]),current_bs,int(brtMatrix[3,i]),brtpoints);
					}
				} else {
					write "Error, the stop does not exist : " + brtMatrix[1,i] + " (" + brtMatrix[3,i] +")" color: #red;
					return;
				}	
			}
			
			// creating n_vehicles for each BRT line
			write "Creating BRT vehicles ...";
			ask BRTLine {
				int n_vehicles <- DEFAULT_NUMBER_BRT;
				do create_vehicles (int(n_vehicles/2), DIRECTION_OUTGOING);
				do create_vehicles (int(n_vehicles/2), DIRECTION_RETURN);
			}	
			ask dummy_geom { do die; }	
		}
		
		/**************************************************************************************************************************/
		/*** TAXI LINES ***/
		/**************************************************************************************************************************/
		if TAXI_ON {
			write "Creating Taxi lines and stations ...";
			create TaxiStop from: marrakesh_taxi_stations with: [stop_id::int(get("ID")), stop_name::get("NAME")]{
				stop_zone <- first(PDUZone overlapping self);
			}
			create dummy_geom from: marrakesh_taxi_lines with:
						[g_id::int(get("ID_TXLINE")),g_name::get("NAME"),g_direction::int(get("DIR")),
							g_var1::int(get("ST_START")),g_var2::int(get("ST_END"))];
			
			loop tx_id over: remove_duplicates(dummy_geom collect (each.g_id)) {
				dummy_geom txout <- dummy_geom first_with (each.g_id = tx_id and each.g_direction = DIRECTION_OUTGOING);
				dummy_geom txret <- dummy_geom first_with (each.g_id = tx_id and each.g_direction = DIRECTION_RETURN);
				
				list<point> txoutpoints <- points_on(txout,25#m);
				list<point> txretpoints <- points_on(txret,25#m);
				create TaxiLine {
					line_id <- tx_id;
					do init_line ("TX"+line_id, txout.shape, txret.shape);
					
					MStop start_ts <- TaxiStop first_with (each.stop_id = txout.g_var1);
					MStop end_ts <- TaxiStop first_with (each.stop_id = txout.g_var2);
					do add_stop(DIRECTION_OUTGOING, start_ts, 0, txoutpoints);
					do add_stop(DIRECTION_OUTGOING, end_ts, 1, txoutpoints);
					do add_stop(DIRECTION_RETURN, end_ts, 0, txretpoints);
					do add_stop(DIRECTION_RETURN, start_ts, 1, txretpoints);
					
					point pp <- first(line_outgoing_stops);
					list<MStop> stops_outgoing <- 
								BusStop where (each distance_to (txoutpoints closest_to each) <= STOP_NEIGHBORING_DISTANCE) +
								BRTStop where (each distance_to (txoutpoints closest_to each) <= STOP_NEIGHBORING_DISTANCE);
					
					stops_outgoing <- stops_outgoing sort_by (pp = txoutpoints closest_to each ?
										0.0 : path_between(line_outgoing_graph, pp, txoutpoints closest_to each).shape.perimeter);
					
					map<MStop,point> outstops <- [];
					loop mstop over: stops_outgoing {
						outstops <+ mstop::txoutpoints closest_to mstop;
						mstop.stop_connected_taxi_lines <+ (self::DIRECTION_OUTGOING);
					}
					line_outgoing_stops <- [line_outgoing_stops.keys[0]::line_outgoing_stops.values[0]] + outstops +
										   [line_outgoing_stops.keys[1]::line_outgoing_stops.values[1]];
					//########################//
					pp <- first(line_return_stops);
					list<MStop> stops_return <- 
								BusStop where (each distance_to (txretpoints closest_to each) <= STOP_NEIGHBORING_DISTANCE) +
								BRTStop where (each distance_to (txretpoints closest_to each) <= STOP_NEIGHBORING_DISTANCE);
					
					stops_return <- stops_return sort_by (pp = txretpoints closest_to each ?
										0.0 : path_between(line_outgoing_graph, pp, txretpoints closest_to each).shape.perimeter);
					
					map<MStop,point> retstops <- [];
					loop mstop over: stops_return {
						retstops <+ mstop::txretpoints closest_to mstop;//pp;
						mstop.stop_connected_taxi_lines <+ (self::DIRECTION_RETURN);//::pp;
					}
					line_return_stops <- [line_return_stops.keys[0]::line_return_stops.values[0]] + retstops +
										 [line_return_stops.keys[1]::line_return_stops.values[1]];
				}
			}
					
			write "Creating Taxi vehicles ...";
			ask TaxiLine {
				int n_vehicles <- DEFAULT_NUMBER_TAXI;
				do create_vehicles (int(n_vehicles/2), DIRECTION_OUTGOING);
				do create_vehicles (int(n_vehicles/2), DIRECTION_RETURN);
			}
			ask dummy_geom { do die; }
		}
		
		/**************************************************************************************************************************/
		/*** STOPS ***/
		/**************************************************************************************************************************/
		//*
		// compute neighbors
		ask BusStop {
			stop_neighbors <- BusStop where (each.stop_zone != nil and each distance_to self <= STOP_NEIGHBORING_DISTANCE)
									sort_by (each distance_to self)
							+ BRTStop where (each.stop_zone != nil and each distance_to self <= STOP_NEIGHBORING_DISTANCE)
									sort_by (each distance_to self);			
		}
		ask BRTStop {
			stop_neighbors <- BusStop where (each.stop_zone != nil and each distance_to self <= STOP_NEIGHBORING_DISTANCE)
									sort_by (each distance_to self)
							+ BRTStop where (each.stop_zone != nil and each distance_to self <= STOP_NEIGHBORING_DISTANCE)
									sort_by (each distance_to self);			
		}
		
		/**************************************************************************************************************************/
		/*** POPULATION ***/
		/**************************************************************************************************************************/
		//*
		write "Creating population ...";
		matrix popMatrix <- matrix(csv_file("../includes/population/populations_5000.csv",true));
		loop i from: 0 to: popMatrix.rows -1 {
			create Individual {
				ind_id <- int(popMatrix[0,i]);
				ind_origin_zone <- PDUZone first_with (each.zone_code = int(popMatrix[1,i]));
				ind_destin_zone <- PDUZone first_with (each.zone_code = int(popMatrix[2,i]));
				ind_origin_stop <- BusStop first_with (each.stop_id = int(popMatrix[3,i]));
				ind_destin_stop <- BusStop first_with (each.stop_id = int(popMatrix[4,i]));					
			}
		}
		
		write "Creating trips ...";
		matrix tripMatrix <- matrix(csv_file("../includes/population/trips_5000.csv",true));
		loop i from: 0 to: tripMatrix.rows -1 {
			create MTrip returns: mytrip {
				self.trip_id <- int(tripMatrix[0,i]);
				self.trip_start_stop <- (agents of_generic_species MStop) first_with (each.stop_id = int(tripMatrix[1,i]));
				self.trip_line <- (agents of_generic_species MLine) first_with (each.line_name = tripMatrix[2,i]);
				self.trip_end_stop <- (agents of_generic_species MStop) first_with (each.stop_id = int(tripMatrix[3,i]));
				self.trip_line_direction <- int(tripMatrix[4,i]);
				self.trip_ride_distance <- int(tripMatrix[5,i]);
			}
		}
		
		write "Creating trip options...";
		matrix popTripMatrix <- matrix(csv_file("../includes/population/pop_trips_5000.csv",true));
		int id_0 <- -1;
		int id_x;
		MTrip mtp;
		Individual indiv_x;
		loop i from: 0 to: popTripMatrix.rows -1 {
			id_x <-  int(popTripMatrix[0,i]);
			if id_x != id_0 {
				id_0 <- id_x;
				indiv_x <- Individual first_with (each.ind_id = id_x);
			}
			indiv_x.ind_trip_options <+ MTrip first_with (each.trip_id = int(popTripMatrix[1,i]))::int(popTripMatrix[2,i]);
		}

		write "Total population: " + length(Individual);
		//*/
		write "--+-- END OF INIT --+--" color:#green;		
	}
	
	/********* end of init definition *********/
	
	/**************************************************************************************************************************/
	/*** TRAVELLING ***/
	/**************************************************************************************************************************/
	int Nminutes <- 10;
	// generate travellers each Nminutes
	reflex going_on when: int(time) mod int(Nminutes#minute) = 0 {
		
		int tt <- int(SIM_START_HOUR) + int(time);
		string hh <- get_time_frag(tt, 1);
		
		if int(hh) = 24 { // midight, end of a day simulation
			do pause;
		}
		/* ####### */
		if int(time) mod int(1#hour) = 0 {
			if int(hh) >= 6 and int(hh) <= 23 { // 06:00 - 23:00 range only
				current_affluence <- hourly_affluence[int(hh)];
			} else {
				current_affluence <- 0.0;
			}
		}
		/* ####### */
		// ask a random number of people (N%) to travel 
		int nn <- int(current_affluence / (60/Nminutes) * length(Individual));
		if nn > 0 {
			write formatted_time() + nn + " new people are travelling ...";
			ask nn among (Individual where !(each.ind_moving or each.ind_arrived)) {
				ind_moving <- true;
				ind_waiting_stop <- ind_origin_stop;
				ind_waiting_stop.stop_waiting_people <+ self;
				ind_times <+ [int(time)]; // waiting time, first trip
			}	
		}
		
		number_of_completed_trips[0] <+ number_of_completed_bus_trips;
		number_of_completed_trips[1] <+ number_of_completed_brt_trips;
		number_of_completed_trips[2] <+ number_of_completed_taxi_trips;
		
		mean_wait_time_completed_trips[0] <+ mean(wtimes_completed_bus_trips)/60;
		mean_wait_time_completed_trips[1] <+ mean(wtimes_completed_brt_trips)/60;
		mean_wait_time_completed_trips[2] <+ mean(wtimes_completed_taxi_trips)/60;
		
		mean_trip_time_completed_trips[0] <+ mean(triptimes_completed_bus_trips)/60;
		mean_trip_time_completed_trips[1] <+ mean(triptimes_completed_brt_trips)/60;
		mean_trip_time_completed_trips[2] <+ mean(triptimes_completed_taxi_trips)/60;
	}
	
	/*******************************************************************************************************************************/
	/*******************************************************************************************************************************/
	
	// Whenever the traffic parameter is updated during simulation
	action traffic_on_off {
		write "Traffic congestion is " + (traffic_on ? "ON" : "OFF");
		ask urban_busses {
			v_speed <- traffic_on ? v_line.line_com_speed : BUS_URBAN_SPEED;
		}
	}
	/*******************************************************************************************************************************/
	/*******************************************************************************************************************************/
}

species dummy_geom {
	int g_id;
	int g_direction; 
	string g_name;
	int g_var1;
	int g_var2;
}

experiment MarraSIM type: gui {
	
	init {
		minimum_cycle_duration <- 0.5;
	}
	
	parameter "Congestion" category:"Traffic" var: traffic_on {ask world {do traffic_on_off;}}
	
	output {
				 
		display Marrakesh type: 3d background: #whitesmoke toolbar:false {
			camera 'default' location: {76609.6582,72520.6097,11625.0305} target: {76609.6582,72520.4068,0.0};
			
			overlay position: {10#px,10#px} size: {100#px,40#px} background: #gray{
	            draw "" + world.formatted_time() at: {20#px, 25#px} font: AFONT0 color: #yellow;
	        }
	        
	       	species PDUZone refresh: false;
			species BusLine refresh: false;
			species TaxiLine refresh: false;
			species BRTLine refresh: false;
			species BusStop refresh: false;
			species BRTStop refresh: false;
			species TaxiStop refresh: false;
			species BusVehicle;
			species TaxiVehicle;
			species BRTVehicle;
		}
		
		display Mobility type: java2D background: #whitesmoke {
			chart "Number of Completed Trips" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {1,0.33} position: {0,0} x_label: "Time" {
				data "BUS" color: #gamablue value: number_of_completed_trips[0] marker_shape: marker_empty;
				data "BRT" color: #darkred value: number_of_completed_trips[1] marker_shape: marker_empty;
				data "TAXI" color: #darkorange value: number_of_completed_trips[2] marker_shape: marker_empty;
			}
			chart "Mean Wait Time of Completed Trips" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {1,0.33} position: {0,0.34} x_label: "Time" {
				data "BUS" color: #gamablue value: mean_wait_time_completed_trips[0] marker_shape: marker_empty;
				data "BRT" color: #darkred value: mean_wait_time_completed_trips[1] marker_shape: marker_empty;
				data "TAXI" color: #darkorange value: mean_wait_time_completed_trips[2] marker_shape: marker_empty;
			}
			chart "Mean Trip Time of Completed Trips" type: series y_tick_line_visible: true x_tick_line_visible: false
				background: #whitesmoke color: #black size: {1,0.33} position: {0,0.67} x_label: "Time" {
				data "BUS" color: #gamablue value: mean_trip_time_completed_trips[0] marker_shape: marker_empty;
				data "BRT" color: #darkred value: mean_trip_time_completed_trips[1] marker_shape: marker_empty;
				data "TAXI" color: #darkorange value: mean_trip_time_completed_trips[2] marker_shape: marker_empty;
			}	
		}
	}
}
