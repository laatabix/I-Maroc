/**
* Name: Main
* Description: this is the main file to launch the MarraSIM model.
* 			The model simulates the public transport traffic in Marrakesh.
* 			The current version of the model includes the bus network.
* 			The Grand Taxi network will be included in the next version.
* 
* Authors: Laatabi
* For the i-Maroc project. 
*/

model MarraSIM
import "classes/PDUZone.gaml"

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
	
	// stats and displayed graphs
	
	/*******************************/
	/******** Initialization *******/
	/*****************************/
	init {
		write "--+-- START OF INIT --+--" color: #green;
		
		
		// create the environment: city, districts, roads, traffic signals
		write "Creating the city environment ...";
		create PDUZone from: marrakesh_pdu with: [pduz_code::int(get("id")), pduz_name::get("label")];
		
		// create busses, bus stops, and connections
		write "Creating busses and bus stops ...";
		create BusStop from: marrakesh_bus_stops with: [stop_id::int(get("stop_numbe")), stop_name::get("stop_name")]{
			stop_zone <- first(PDUZone overlapping self);
		}
		
		create dummy_geom from: marrakesh_bus_lines with: [g_name::get("NAME"),g_direction::int(get("DIR"))];
		matrix dataMatrix <- matrix(csv_file("../includes/gis/bus_network/bus_lines_stops.csv",true));
		
		loop i from: 0 to: dataMatrix.rows -1 {
			string bus_line_name <- dataMatrix[0,i];
			
			if !(bus_line_name in ["L40","L41","L332","L19","BRT1"]) { 
				// create the bus line if it does not exist yet
				BusLine current_bl <- first(BusLine where (each.line_name = bus_line_name));
				
				if current_bl = nil {
					create BusLine returns: my_busline { line_name <- bus_line_name; }
					current_bl <- my_busline[0];
					ask current_bl {
						line_outgoing_shape <- (dummy_geom first_with (each.g_name = line_name and each.g_direction = DIRECTION_OUTGOING)).shape;
						line_return_shape <- (dummy_geom first_with (each.g_name = line_name and each.g_direction = DIRECTION_RETURN)).shape;
						line_outgoing_path <- path(line_outgoing_shape);
						line_return_path <- path(line_return_shape);
						shape <- line_outgoing_shape + line_return_shape;
					}
				}
				
				MStop current_bs <- BusStop first_with (each.stop_id = int(dataMatrix[3,i]));
				if current_bs != nil {
					if int(dataMatrix[1,i]) = DIRECTION_OUTGOING {
						if length(current_bl.line_outgoing_stops) != int(dataMatrix[2,i]) {
							write "Error in order of bus stops!" color: #red;
						}
						current_bl.line_outgoing_stops <+ current_bs::current_bl.line_outgoing_shape.points closest_to current_bs;
					} else {
						if length(current_bl.line_return_stops) != int(dataMatrix[2,i]) {
							write "Error in order of bus stops!" color: #red;
						}
						current_bl.line_return_stops <+ current_bs::current_bl.line_return_shape.points closest_to current_bs;
					}
				} else {
					write "Error, the bus stop does not exist : " + dataMatrix[3,i] + " (" + dataMatrix[1,i] +")" color: #red;
					return;
				}	
			}
		}
		
		// creating n_vehicles for each bus line
		write "Creating bus vehicles ...";
		dataMatrix <- matrix(csv_file("../includes/gis/bus_network/bus_lines_data.csv",true));
		ask BusLine {
			int n_vehicles <- 2;//BL_DEFAULT_NUMBER_OF_VEHICLES;
			if dataMatrix index_of line_name != nil {
				line_com_speed <- float(dataMatrix[7, int((dataMatrix index_of line_name).y)]) #km/#h;
			}
			loop i from: 0 to: (n_vehicles/2)-1 {
				create BusVehicle {
					v_line <- myself;				
					v_current_bs <- v_line.line_outgoing_stops.keys[0];
					v_next_bs <- v_current_bs;
					v_next_loc <- v_line.line_outgoing_stops.values[0];
					v_current_direction <- DIRECTION_OUTGOING;
					location <- v_line.line_outgoing_stops at v_current_bs;
				}
			}
			loop i from: 0 to: (n_vehicles/2)-1 {
				create BusVehicle {
					v_line <- myself;				
					v_current_bs <- v_line.line_return_stops.keys[0];
					v_next_bs <- v_current_bs;
					v_next_loc <- v_line.line_return_stops.values[0];
					v_current_direction <- DIRECTION_RETURN;
					location <- v_line.line_return_stops at v_current_bs;
				}	
			}
		}	
		
		// clean
		ask dummy_geom { do die; }
		ask BusStop - remove_duplicates(BusLine accumulate (each.line_outgoing_stops.keys + each.line_return_stops.keys)) {
			do die;
		}

		/**************************************************************************************************************************/
		write "Creating BRT stops and lines  ...";
		create BRTStop from: marrakesh_brt_stops with: [stop_id::int(get("ID")), stop_name::get("NAME")]{
			stop_zone <- first(PDUZone overlapping self);
		}

		create dummy_geom from: marrakesh_brt_lines with: [g_id::int(get("ID")),g_name::get("NAME")];
		dataMatrix <- matrix(csv_file("../includes/gis/BRT_network/BRT_lines_stations.csv",true));
		
		loop i from: 0 to: dataMatrix.rows -1 {
			int idbrt <- int(dataMatrix[0,i]);

			// create the bus line if it does not exist yet
			BRTLine current_bl <- first(BRTLine where (each.line_id = idbrt));
			
			if current_bl = nil {
				create BRTLine returns: my_brt { line_id <- idbrt; }
				current_bl <- my_brt[0];
				dummy_geom mygeom <- dummy_geom first_with (each.g_id = idbrt);
				ask current_bl {
					line_name <- mygeom.g_name;
					line_outgoing_shape <- mygeom.shape;
					line_return_shape <- mygeom.shape;
					line_outgoing_path <- path(line_outgoing_shape);
					line_return_path <- path(line_return_shape);
					shape <- line_outgoing_shape + line_return_shape;
				}
			}

			MStop current_bs <- BRTStop first_with (each.stop_id = int(dataMatrix[1,i]));
			if current_bs != nil {
				if int(dataMatrix[2,i]) = DIRECTION_OUTGOING {
					if length(current_bl.line_outgoing_stops) != int(dataMatrix[3,i]) {
						write "Error in order of BRT stops!" color: #red;
					}
					current_bl.line_outgoing_stops <+ current_bs::current_bl.line_outgoing_shape.points closest_to current_bs;
				} else {
					if length(current_bl.line_return_stops) != int(dataMatrix[3,i]) {
						write "Error in order of BRT stops!" color: #red;
					}
					current_bl.line_return_stops <+ current_bs::current_bl.line_return_shape.points closest_to current_bs;
				}
			} else {
				write "Error, the BRT stop does not exist : " + dataMatrix[1,i] + " (" + dataMatrix[3,i] +")" color: #red;
				return;
			}	
		}
		
		// creating n_vehicles for each bus line
		write "Creating BRT vehicles ...";
		ask MLine {
			int n_vehicles <- 2;
			loop i from: 0 to: (n_vehicles/2)-1 {
				create MVehicle {
					v_line <- myself;				
					v_current_bs <- v_line.line_outgoing_stops.keys[0];
					v_next_bs <- v_current_bs;
					v_next_loc <- v_line.line_outgoing_stops.values[0];
					v_current_direction <- DIRECTION_OUTGOING;
					location <- v_line.line_outgoing_stops at v_current_bs;
				}
			}
			loop i from: 0 to: (n_vehicles/2)-1 {
				create MVehicle {
					v_line <- myself;				
					v_current_bs <- v_line.line_return_stops.keys[0];
					v_next_bs <- v_current_bs;
					v_next_loc <- v_line.line_return_stops.values[0];
					v_current_direction <- DIRECTION_RETURN;
					location <- v_line.line_return_stops at v_current_bs;
				}	
			}
		}
		ask dummy_geom { do die; }
		
		
		/**************************************************************************************************************************/
		create TaxiStop from: marrakesh_taxi_stations with: [stop_id::int(get("ID")), stop_name::get("NAME")];
		create dummy_geom from: marrakesh_taxi_lines with:
					[g_id::int(get("ID_TXLINE")),g_name::get("NAME"),g_direction::int(get("DIR")),
						g_var1::int(get("ST_START")),g_var2::int(get("ST_END"))];
		
		loop tx_id over: remove_duplicates(dummy_geom collect (each.g_id)) {
			dummy_geom out <- dummy_geom first_with (each.g_id = tx_id and each.g_direction = DIRECTION_OUTGOING);
			dummy_geom ret <- dummy_geom first_with (each.g_id = tx_id and each.g_direction = DIRECTION_RETURN);
			create TaxiLine {
				line_id <- tx_id;
				line_name <- out.g_name;
				line_outgoing_shape <- out.shape;
				line_return_shape <- ret.shape;
				line_outgoing_path <- path(line_outgoing_shape);
				line_return_path <- path(line_return_shape);
				shape <- line_outgoing_shape + line_return_shape;
				
				MStop start_ts <- TaxiStop first_with (each.stop_id = out.g_var1);
				MStop end_ts <- TaxiStop first_with (each.stop_id = out.g_var2);
				line_outgoing_stops <+ start_ts::line_outgoing_shape.points closest_to start_ts;
				line_outgoing_stops <+ end_ts::line_outgoing_shape.points closest_to end_ts;
				line_return_stops <+ end_ts::line_return_shape.points closest_to end_ts;
				line_return_stops <+ start_ts::line_return_shape.points closest_to start_ts;
			}
		}
		
		// creating n_vehicles for each bus line
		write "Creating Taxi vehicles ...";
		ask TaxiLine {
			int n_vehicles <- 4;
			loop i from: 0 to: (n_vehicles/2)-1 {
				create TaxiVehicle {
					v_line <- myself;				
					v_current_bs <- v_line.line_outgoing_stops.keys[0];
					v_next_bs <- v_current_bs;
					v_next_loc <- v_line.line_outgoing_stops.values[0];
					v_current_direction <- DIRECTION_OUTGOING;
					location <- v_line.line_outgoing_stops at v_current_bs;
				}
			}
			loop i from: 0 to: (n_vehicles/2)-1 {
				create TaxiVehicle {
					v_line <- myself;				
					v_current_bs <- v_line.line_return_stops.keys[0];
					v_next_bs <- v_current_bs;
					v_next_loc <- v_line.line_return_stops.values[0];
					v_current_direction <- DIRECTION_RETURN;
					location <- v_line.line_return_stops at v_current_bs;
				}	
			}
		}
		ask dummy_geom { do die; }
		
		/****** */
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
				 
		display Marrakesh type: opengl background: #whitesmoke {
			camera 'default' location: {76609.6582,72520.6097,11625.0305} target: {76609.6582,72520.4068,0.0};
			
			overlay position: {10#px,10#px} size: {100#px,40#px} background: #gray{
	            draw "" + world.formatted_time() at: {20#px, 25#px} font: AFONT0 color: #yellow;
	        }
	       	 
	       	species PDUZone refresh: false;
			species BusLine refresh: false;
			species BRTLine refresh: false;
			species TaxiLine refresh: false;
			species BusStop refresh: false;
			species BRTStop refresh: false;
			species TaxiStop refresh: false;
			//species BusVehicle;
			//species BRTVehicle;
			//species TaxiVehicle;
		}
	}
}
