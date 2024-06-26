/**
* Name: Trip_Generator
* Description: Trip_Generator allows to generate all possible travel options (trips) for the given population.
* 				The result is stored into a file to be read and use by the main model.
* Authors: Laatabi
* For the i-Maroc project. 
*/

model Trip_Generator

import "PDUZone.gaml"
import "Individual.gaml"

global {
	
		// shapefiles of the model environment
	file marrakesh_pdu <- shape_file("../../includes/gis/PDU_zoning/zonage_pdu.shp"); // PDU (Plan de Déplacement Urbain) zoning
	
	file marrakesh_bus_lines <- shape_file("../../includes/gis/bus_network/bus_lines.shp"); // bus_lines
	file marrakesh_bus_stops <- shape_file("../../includes/gis/bus_network/bus_stops.shp"); // bus stops
	
	file marrakesh_brt_lines <- shape_file("../../includes/gis/BRT_network/BRT_lines.shp"); // bus_lines
	file marrakesh_brt_stops <- shape_file("../../includes/gis/BRT_network/BRT_stations.shp"); // bus stops
	
	file marrakesh_taxi_lines <- shape_file("../../includes/gis/taxi_network/taxi_lines.shp"); // bus_lines
	file marrakesh_taxi_stations <- shape_file("../../includes/gis/taxi_network/taxi_stations.shp"); // bus stops
	
	// shape of the environment (the convex hull of regional roads shapefile)
	geometry shape <- envelope (marrakesh_bus_lines);
	
	init {
		write "--+-- START OF INIT --+--" color: #green;
		
		// create the environment: city, districts, roads, traffic signals
		write "Creating the city environment ...";
		create PDUZone from: marrakesh_pdu with: [zone_code::int(get("id")), zone_name::get("label")];
		
		/**************************************************************************************************************************/
		/*** BUS LINES ***/
		/**************************************************************************************************************************/
		// create busses, bus stops
		//*
		write "Creating bus lines and bus stops ...";
		create BusStop from: marrakesh_bus_stops with: [stop_id::int(get("ID")), stop_name::get("NAME"),
								stop_zone::PDUZone first_with(each.zone_code = int(get("pduzone_id")))]{
			if stop_zone = nil {
				stop_zone <- PDUZone where (each distance_to self <= STOP_NEIGHBORING_DISTANCE) with_min_of (each distance_to self);
			}
		}
		//*
		create dummy_geom from: marrakesh_bus_lines with: [g_name::get("NAME"),g_direction::int(get("DIR"))];
		matrix busMatrix <- matrix(csv_file("../../includes/gis/bus_network/bus_lines_stops.csv",true));
		
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
					bsoutpoints <- points_on(bsout,25#meter);
					bsretpoints <- points_on(bsret,25#meter);
					
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
					write "Error, the bus stop does not exist : " + busMatrix[3,i] + " (" + busMatrix[1,i] +")" color: #red;
					return;
				}	
			}
		}
		// clean and prepare
		ask BusStop - remove_duplicates(BusLine accumulate (each.line_outgoing_stops.keys + each.line_return_stops.keys)) {
			do die;
		}
		ask dummy_geom { do die; }
		/**************************************************************************************************************************/
		/*** BRT LINES ***/
		/**************************************************************************************************************************/
		//*
		write "Creating BRT stops and lines ...";
		create BRTStop from: marrakesh_brt_stops with: [stop_id::int(get("ID")), stop_name::get("NAME"),
								stop_zone::PDUZone first_with(each.zone_code = int(get("pduzone_id")))]{
			if stop_zone = nil {
				stop_zone <- PDUZone where (each distance_to self <= STOP_NEIGHBORING_DISTANCE) with_min_of (each distance_to self);
			}
		}
		create dummy_geom from: marrakesh_brt_lines with: [g_id::int(get("ID")),g_name::get("NAME")];
		matrix brtMatrix <- matrix(csv_file("../../includes/gis/BRT_network/BRT_lines_stations.csv",true));

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
				write "Error, the BRT stop does not exist : " + brtMatrix[1,i] + " (" + brtMatrix[3,i] +")" color: #red;
				return;
			}	
		}
		ask dummy_geom { do die; }	
		/**************************************************************************************************************************/
		/*** TAXI LINES ***/
		/**************************************************************************************************************************/
		//*
		write "Creating Taxi lines and stations ...";
		create TaxiStop from: marrakesh_taxi_stations with: [stop_id::int(get("ID")), stop_name::get("NAME"),
								stop_zone::PDUZone first_with(each.zone_code = int(get("pduzone_id")))]{
			if stop_zone = nil {
				stop_zone <- PDUZone where (each distance_to self <= STOP_NEIGHBORING_DISTANCE) with_min_of (each distance_to self);
			}
		}
		create dummy_geom from: marrakesh_taxi_lines with:
						[g_id::int(get("ID_TXLINE")),g_name::get("NAME"),g_direction::int(get("DIR")),
							g_var1::int(get("ST_START")),g_var2::int(get("ST_END"))];
			
			loop tx_id over: remove_duplicates(dummy_geom collect (each.g_id)) {
				dummy_geom txout <- dummy_geom first_with (each.g_id = tx_id and each.g_direction = DIRECTION_OUTGOING);
				dummy_geom txret <- dummy_geom first_with (each.g_id = tx_id and each.g_direction = DIRECTION_RETURN);
				
				list<point> txoutpoints <- points_on(txout,50#m);
				list<point> txretpoints <- points_on(txret,50#m);
				create TaxiLine {
					line_id <- tx_id;
					do init_line ("TX"+line_id, txout.shape, txret.shape);
					TaxiStop start_ts <- TaxiStop first_with (each.stop_id = txout.g_var1);
					TaxiStop end_ts <- TaxiStop first_with (each.stop_id = txout.g_var2);
					
					point pp <- txoutpoints closest_to start_ts;
					list<MStop> stops_outgoing <- [start_ts, end_ts] +
								BusStop where (each distance_to (txoutpoints closest_to each) <= STOP_NEIGHBORING_DISTANCE) +
								BRTStop where (each distance_to (txoutpoints closest_to each) <= STOP_NEIGHBORING_DISTANCE);
					
					stops_outgoing <- stops_outgoing sort_by (pp = txoutpoints closest_to each ?
										0.0 : path_between(line_outgoing_graph, pp, txoutpoints closest_to each).shape.perimeter);
					
					loop mstop over: stops_outgoing {
						line_outgoing_stops <+ mstop::txoutpoints closest_to mstop;
						mstop.stop_connected_taxi_lines <+ (self::DIRECTION_OUTGOING);
					}
					line_outgoing_locations <- remove_duplicates(line_outgoing_stops.values);
					loop i from: 1 to: length(line_outgoing_locations) - 1 {
						line_outgoing_dists<+ line_outgoing_locations[i] = line_outgoing_locations[i-1] ?
												0 : int(path_between(line_outgoing_graph, line_outgoing_locations[i],
													line_outgoing_locations[i-1]).shape.perimeter);
					}
					//########################//
					pp <- txretpoints closest_to end_ts;
					list<MStop> stops_return <- [start_ts, end_ts] +
								BusStop where (each distance_to (txretpoints closest_to each) <= STOP_NEIGHBORING_DISTANCE) +
								BRTStop where (each distance_to (txretpoints closest_to each) <= STOP_NEIGHBORING_DISTANCE);
					
					stops_return <- stops_return sort_by (pp = txretpoints closest_to each ?
										0.0 : path_between(line_return_graph, pp, txretpoints closest_to each).shape.perimeter);
					
					loop mstop over: stops_return {
						line_return_stops <+ mstop::txretpoints closest_to mstop;
						mstop.stop_connected_taxi_lines <+ (self::DIRECTION_RETURN);
					}
					line_return_locations <- remove_duplicates(line_return_stops.values);
					loop i from: 1 to: length(line_return_locations) - 1 {
						line_return_dists<+ line_return_locations[i] = line_return_locations[i-1] ?
											0 : int(path_between(line_return_graph, line_return_locations[i],
												line_return_locations[i-1]).shape.perimeter);
					}
				}
			}
			ask dummy_geom { do die; }		
		/**************************************************************************************************************************/
		/*** STOPS ***/
		/**************************************************************************************************************************/
		//*
		// compute neighbors
		ask BusStop where (each.stop_zone != nil){
			stop_neighbors <- BusStop where (each.stop_zone != nil and each distance_to self <= STOP_NEIGHBORING_DISTANCE)
									sort_by (each distance_to self)
							+ BRTStop where (each.stop_zone != nil and each distance_to self <= STOP_NEIGHBORING_DISTANCE)
									sort_by (each distance_to self);
			stop_zone.zone_stops <+ self; 			
		}
		ask BRTStop where (each.stop_zone != nil){
			stop_neighbors <- BusStop where (each.stop_zone != nil and each distance_to self <= STOP_NEIGHBORING_DISTANCE)
									sort_by (each distance_to self)
							+ BRTStop where (each.stop_zone != nil and each distance_to self <= STOP_NEIGHBORING_DISTANCE)
									sort_by (each distance_to self);
			stop_zone.zone_stops <+ self; 		
		}
		ask TaxiStop where (each.stop_zone != nil){
			stop_neighbors <- BusStop where (each.stop_zone != nil and each distance_to self <= STOP_NEIGHBORING_DISTANCE)
									sort_by (each distance_to self)
							+ BRTStop where (each.stop_zone != nil and each distance_to self <= STOP_NEIGHBORING_DISTANCE)
									sort_by (each distance_to self);
			stop_zone.zone_stops <+ self; 		
		}
		//*/
		/**************************************************************************************************************************/
		/*** POPULATION ***/
		/**************************************************************************************************************************/
		//*
		write "Creating population ...";
		matrix<int> ODMatrix <- matrix<int>(csv_file("../../includes/mobility/Bus_OD_Matrix.csv",false));
		loop i from: 0 to: ODMatrix.rows -1 {
			PDUZone o_zone <- PDUZone first_with (each.zone_code = i+1);
			list<MStop> obstops <- BusStop where (each.stop_zone = o_zone);
			if !empty(obstops) {
				loop j from: 0 to: ODMatrix.columns -1{
					PDUZone d_zone <- PDUZone first_with (each.zone_code = j+1);
					list<MStop> dbstops <- BusStop where (each.stop_zone = d_zone);
					if !empty(dbstops) {
						create Individual number: ODMatrix[j,i]{
							ind_id <- int(self);
							ind_origin_zone <- o_zone;
							ind_destin_zone <- d_zone;
							ind_origin_stop <- one_of(obstops);
							// distance between origin and destination must be greater than the neighboring distance, or take a walk !
							// prevent very short trips (<= STOP_NEIGHBORING_DISTANCE);
							ind_destin_stop <- one_of(dbstops where (each distance_to ind_origin_stop > STOP_NEIGHBORING_DISTANCE));
							if ind_destin_stop = nil {
								ind_destin_stop <- last(dbstops sort_by (each distance_to self));
							}
						}
					}
				}
			}	
		}
		write "Total population: " + length(Individual);	
				
		/*
		create Individual  {
			ind_origin_stop <- BusStop first_with(each.stop_id=33);
			ind_destin_stop <- BusStop first_with(each.stop_id=78);
			ind_origin_zone <- ind_origin_stop.stop_zone;
			ind_destin_zone <- ind_destin_stop.stop_zone;
		}
		*/			
		
		write "Generating trip options ..";
		list<Individual> individuals <- 500 among Individual; //TODO number ?
		
		ask individuals {
			// if another individual with the same origin and destination bus stops has already a planning, just copy it
			Individual indiv <- first(individuals where (!empty(each.ind_trip_options) and
							each.ind_origin_stop = self.ind_origin_stop and each.ind_destin_stop = self.ind_destin_stop));
			if indiv != nil {
				self.ind_trip_options <- copy (indiv.ind_trip_options);	
			} else { // else, compute
				do find_trip_options;
			}
			write ind_id; // watch processing ...
		}
		
		write "1 - Population with trip options : " + length(individuals where !empty(each.ind_trip_options));
		
		write "Recomputing planning for individuals without trip options..";
		int counter <- 0;
		ask individuals where (empty(each.ind_trip_options)) {
			write counter;
			Individual indiv <- one_of(individuals where (!empty(each.ind_trip_options) and
							each.ind_origin_zone = self.ind_origin_zone and each.ind_destin_zone = self.ind_destin_zone));
			if indiv = nil {
				indiv <- one_of(individuals where (!empty(each.ind_trip_options)));
			}
			if indiv != nil {
				self.ind_origin_zone <- indiv.ind_origin_zone;
				self.ind_destin_zone <- indiv.ind_destin_zone;
				self.ind_origin_stop <- indiv.ind_origin_stop;
				self.ind_destin_stop <- indiv.ind_destin_stop;
				self.ind_trip_options <- copy(indiv.ind_trip_options);	
			}
			counter <- counter + 1;
		}
		write "2 - Population with trip options : " + length(individuals where !empty(each.ind_trip_options));
		
		//###################################
		write "Preparing data ...";
		
		bool bool_var <- delete_file("../../includes/population/populations.csv");
		string ss <- "ind,ozone,dzone,ostop,dstop" + "\n";
		int N <- length(individuals);
		loop i from: 0 to: N-1 {
			ask individuals[i] {
				ss <- ss + ind_id + ',' + ind_origin_zone.zone_code + ',' + ind_destin_zone.zone_code + ',' + 
								ind_origin_stop.stop_id + ',' + ind_destin_stop.stop_id + '\n';
			}
			if i mod 1000 = 0 or i = N-1 {
				write "Saving populations to text files ...";
				save copy_between(ss,0,length(ss)-1) format: 'text' rewrite: false to: "../../includes/population/populations.text";
				ss <- "";
			}
		}
		bool_var <- rename_file("../../includes/population/populations.text","../../includes/population/populations.csv");
		//###################################
		
		bool_var <- delete_file("../../includes/population/trips.csv");
		ss <- "id,startstop,ligne,endstop,dir,ridedist" + "\n";
		N <- length(MTrip);
		loop i from: 0 to: N-1 {
			ask MTrip[i] {
				ss <- ss + trip_id + ',' + trip_start_stop.stop_id + ',' + trip_line.line_name + ',' +
							trip_end_stop.stop_id + ',' + trip_line_direction + ',' + trip_ride_distance + '\n';
			}
			// saving each 1000 individuals apart to avoid memory problems in case of large datasets
			if i mod 1000 = 0 or i = N-1 {
				write "Saving trips to text files ...";
				save copy_between(ss,0,length(ss)-1) format: 'text' rewrite: false to: "../../includes/population/trips.text";
				ss <- "";
			}
		}
		bool_var <- rename_file("../../includes/population/trips.text","../../includes/population/trips.csv");
		//###################################
		
		bool_var <- delete_file("../../includes/population/pop_trips.csv");
		ss <- "ind,trip,type" + "\n";
		N <- length(individuals);
		loop i from: 0 to: N-1 {
			ask individuals[i] {
				loop trp over: ind_trip_options.keys {
					ss <- ss + ind_id + ',' + trp.trip_id + ',' + ind_trip_options at trp + '\n';
				}
			}
			if i mod 1000 = 0 or i = N-1 {
				write "Saving trip options to text files ...";
				save copy_between(ss,0,length(ss)-1) format: 'text' rewrite: false to: "../../includes/population/pop_trips.text";
				ss <- "";
			}
		}
		bool_var <- rename_file("../../includes/population/pop_trips.text","../../includes/population/pop_trips.csv");	
		
		//*/
		write "--+-- DONE --+--" color: #green;		
	}
}

species dummy_geom {
	int g_id;
	int g_direction; 
	string g_name;
	int g_var1;
	int g_var2;
}

experiment Trip_Generator {}

