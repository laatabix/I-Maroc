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
import "marrasim_classes/PDUZone.gaml"

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
	font AFONT0 <- font("Calibri", 16, #bold);
	
	
	/*******************************/
	/******** Initialization *******/
	/*****************************/
	init {
		write "--+-- START OF INIT --+--" color: #green;
		
		// create the environment: city, districts, roads, traffic signals
		write "Creating the city environment ...";
		create PDUZone from: marrakesh_pdu with: [pduz_code::int(get("id")), pduz_name::get("label")];
		city_area <- envelope(PDUZone);
		
		/******************/
		/*** BUS LINES ***/
		/**************************************************************************************************************************/
		// create busses, bus stops, and connections
		/*
		write "Creating busses and bus stops ...";
		create BusStop from: marrakesh_bus_stops with: [stop_id::int(get("stop_numbe")), stop_name::get("stop_name")]{
			stop_zone <- first(PDUZone overlapping self);
		}
		
		create dummy_geom from: marrakesh_bus_lines with: [g_name::get("NAME"),g_direction::int(get("DIR"))];
		matrix busMatrix <- matrix(csv_file("../includes/gis/bus_network/bus_lines_stops.csv",true));
		
		dummy_geom bsout;
		dummy_geom bsret;
		list<point> bsoutpoints;
		list<point> bsretpoints;
		loop i from: 0 to: busMatrix.rows -1 {
			string bus_line_name <- busMatrix[0,i];
			
			if !(bus_line_name in ["L40","L41","L332","L19","BRT1"]) { 
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

		// creating n_vehicles for each bus line
		write "Creating bus vehicles ...";
		matrix busDataMatrix <- matrix(csv_file("../includes/gis/bus_network/bus_lines_data.csv",true));
		ask BusLine {
			int n_vehicles <- 2;
			if busDataMatrix index_of line_name != nil {
				line_com_speed <- float(busDataMatrix[7, int((busDataMatrix index_of line_name).y)]) #km/#h;
			}
			do create_vehicles (int(n_vehicles/2), DIRECTION_OUTGOING);
			do create_vehicles (int(n_vehicles/2), DIRECTION_RETURN);
		}	
		
		// clean
		ask dummy_geom { do die; }
		ask BusStop - remove_duplicates(BusLine accumulate (each.line_outgoing_stops.keys + each.line_return_stops.keys)) {
			do die;
		}
		//*/
		/******************/
		/*** BRT LINES ***/
		/**************************************************************************************************************************/
		/*
		write "Creating BRT stops and lines ...";
		create BRTStop from: marrakesh_brt_stops with: [stop_id::int(get("ID")), stop_name::get("NAME")]{
			stop_zone <- first(PDUZone overlapping self);
		}

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
					do init_line (brtgeom.g_name, brtgeom.shape, brtgeom.shape);
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
			int n_vehicles <- 2;
			do create_vehicles (int(n_vehicles/2), DIRECTION_OUTGOING);
			do create_vehicles (int(n_vehicles/2), DIRECTION_RETURN);
		}
		ask dummy_geom { do die; }
		//*/
		/******************/
		/*** TAXI LINES ***/
		/**************************************************************************************************************************/
		//*
		write "Creating Taxi lines and stations ...";
		create TaxiStop from: marrakesh_taxi_stations with: [stop_id::int(get("ID")), stop_name::get("NAME")];
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
				do init_line (txout.g_name, txout.shape, txret.shape);
				
				MStop start_ts <- TaxiStop first_with (each.stop_id = txout.g_var1);
				MStop end_ts <- TaxiStop first_with (each.stop_id = txout.g_var2);
				do add_stop(DIRECTION_OUTGOING, start_ts, 0, txoutpoints);
				do add_stop(DIRECTION_OUTGOING, end_ts, 1, txoutpoints);
				do add_stop(DIRECTION_RETURN, end_ts, 0, txretpoints);
				do add_stop(DIRECTION_RETURN, start_ts, 1, txretpoints);
			}
		}
				
		write "Creating Taxi vehicles ...";
		ask TaxiLine {
			int n_vehicles <- 2;
			do create_vehicles (int(n_vehicles/2), DIRECTION_OUTGOING);
			do create_vehicles (int(n_vehicles/2), DIRECTION_RETURN);
		}
		ask dummy_geom { do die; }
		
		/*******/
		
		ask BusLine - (BusLine inside city_area) {
			sub_urban_vehicles <<+ BusVehicle where (each.v_line = self);
		}
		
		write "--+-- END OF INIT --+--" color:#green;		
	}
	
	/*** end of init definition ***/
	
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
	}
}
