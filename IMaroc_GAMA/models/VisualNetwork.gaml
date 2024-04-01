/**
* Name: VisualNetwork
* Based on the internal skeleton template. 
* Author: Laatabi
* Tags: 
*/

model VisualNetwork

global {
	file marrakesh_pdu_shp <- shape_file("../includes/gis/PDU_zoning/zonage_pdu.shp"); 
	file bus_lines_shp <- shape_file("../includes/gis/bus_network/bus_lines.shp");
	file bus_stops_shp <- shape_file("../includes/gis/bus_network/bus_stops.shp");
	file taxi_lines_shp <- shape_file("../includes/gis/taxi_network/taxi_lines.shp");
	file taxi_stations_shp <- shape_file("../includes/gis/taxi_network/taxi_stations.shp");
	
	geometry shape <- envelope (marrakesh_pdu_shp);
	
	int DIRECTION_OUTGOING <- 1;
	int DIRECTION_RETURN <- 2;
	
	int DIRECTION_INNER <- -1;
	int DIRECTION_OUTER <- 1;
	
	float SHIFT_DISTANCE <- 20#m;
	//bool return_above <- true;
	
	point g1;
	point g2;
	
	
	init {
		
		create PDUZone from: marrakesh_pdu_shp with: [pduz_code::int(get("id")), pduz_name::get("label")];
		
		/**********************/
		/******* TAXIS *******/
		/********************/
		
		create TaxiStation from: taxi_stations_shp with: [ts_id::int(get("ID")), ts_name::get("NAME")];
		create dummy_geom from: taxi_lines_shp with:
					[varstr0::get("ID_TXLINE"),varstr1::get("NAME"),varint1::int(get("DIR")),
						varint2::int(get("ST_START")),varint3::int(get("ST_END"))];
		
		loop tx_id over: remove_duplicates(dummy_geom collect (each.varstr0)) {
			dummy_geom out <- dummy_geom first_with (each.varstr0 = tx_id and each.varint1 = DIRECTION_OUTGOING);
			dummy_geom ret <- dummy_geom first_with (each.varstr0 = tx_id and each.varint1 = DIRECTION_RETURN);
			create TaxiLine {
				tl_id <- tx_id;
				tl_name <- out.varstr1;
				tl_start_ts <- TaxiStation first_with (each.ts_id = out.varint2);
				tl_end_ts <- TaxiStation first_with (each.ts_id = out.varint3);
				tl_outgoing_geom <- out.shape;
				tl_return_geom <- ret.shape;
				//shape <- tl_outgoing_geom + tl_return_geom;
			}
		}
		
		ask dummy_geom { do die; } // DEL temporary agents
				
		ask TaxiLine where !(each.tl_id in ["TX4"]){ do die;}
		
		ask TaxiLine {
			write "---------------- " + self.tl_name;
			
			if self.tl_outgoing_geom overlaps self.tl_return_geom {
				
				
				self.tl_return_geom <- world.shift_line(self.tl_return_geom, self.tl_outgoing_geom);
			}
			

			
	
			/*loop txl over: (TaxiLine - self) {
				write txl.tl_name;
				if self.tl_outgoing_geom overlaps txl.tl_outgoing_geom {//} and !(self.tl_outgoing_geom touches txl.tl_outgoing_geom)  {
					self.tl_outgoing_geom <- world.shift_line(self.tl_outgoing_geom, txl.tl_outgoing_geom);
				}
				
				if self.tl_outgoing_geom overlaps txl.tl_return_geom{//} and !(self.tl_outgoing_geom touches txl.tl_return_geom)  {
					self.tl_outgoing_geom <- world.shift_line(self.tl_outgoing_geom, txl.tl_return_geom);
				}
				
				if self.tl_return_geom overlaps txl.tl_return_geom {//and !(self.tl_return_geom touches txl.tl_return_geom)  {
					self.tl_return_geom <- world.shift_line(self.tl_return_geom, txl.tl_return_geom);
				}
				
				if self.tl_return_geom overlaps txl.tl_outgoing_geom {//} and !(self.tl_return_geom touches txl.tl_outgoing_geom)  {
					self.tl_return_geom <- world.shift_line(self.tl_return_geom, txl.tl_outgoing_geom);
				}
			}*/
			self.shape <- self.tl_outgoing_geom + self.tl_return_geom;
		}
		
		/********************/
		/******* BUS *******/
		/******************/
		
		//create dummy_geom from: bus_network with: [g_name::get("NAME"),g_direction::int(get("DIR"))];
		/*create BusStop from: marrakesh_bus_stops with: [bs_id::int(get("stop_numbe")), bs_name::get("stop_name")]{
			bs_zone <- first(PDUZone overlapping self);
		}
		
		matrix dataMatrix <- matrix(csv_file("../includes/gis/bus_network/bus_lines_stops.csv",true));
		loop i from: 0 to: dataMatrix.rows -1 {
			string bus_line_name <- dataMatrix[0,i];
			
			// create the bus line if it does not exist yet
			BusLine current_bl <- BusLine first_with (each.bl_name = bus_line_name);
			if current_bl = nil {
				create BusLine returns: my_busline {
					bl_name <- bus_line_name;
					bl_outgoing_geom <- dummy_geom first_with (each.g_name = bl_name and each.g_direction = BL_DIRECTION_OUTGOING);
					bl_return_geom <- dummy_geom first_with (each.g_name = bl_name and each.g_direction = BL_DIRECTION_RETURN);
					shape <- bl_outgoing_geom;// + bl_return_geom;
					bl_points <- shape.points;
					bl_segments <- world.points_to_segments (bl_points);
				}
				current_bl <- my_busline[0];
			}

			BusStop current_bs <- BusStop first_with (each.bs_id = int(dataMatrix[3,i]));
			if current_bs != nil {
				if int(dataMatrix[1,i]) = BL_DIRECTION_OUTGOING {
					if length(current_bl.bl_outgoing_bs) != int(dataMatrix[2,i]) {
						write "Error in order of bus stops!" color: #red;
					}
					current_bl.bl_outgoing_bs <+ current_bs::current_bl.bl_outgoing_geom.points closest_to current_bs;
				} else {
					if length(current_bl.bl_return_bs) != int(dataMatrix[2,i]) {
						write "Error in order of bus stops!" color: #red;
					}
					current_bl.bl_return_bs <+ current_bs::current_bl.bl_return_geom.points closest_to current_bs;
				}
			} else {
				write "Error, the bus stop does not exist : " + dataMatrix[3,i] + " (" + dataMatrix[1,i] +")" color: #red;
				return;
			}	
		}
		// remove temp agents
		ask dummy_geom {
			do die;
		}
				
		ask BusLine where !(each.bl_name in ["L12","L1"]) {
			do die;
		}*/
	}
	
	geometry shift_line (geometry geom, geometry overlap_geom) {
		list<geometry> geom_segments <- to_segments(geom);
		list<geometry> geoms_to_shift <- [];
		list<geometry> geoms_to_keep <- [];
		list<geometry> shifted_geoms <- [];
		list<list<point>> touching_points <- [];
		
		int my_index <- 0;
		bool increase_index <- false;
		
		// cut the geometry line into a set of segments where it overlaps with another geometry line
		loop i from: 0 to: length(geom_segments)-1 {
			geometry g <- geom_segments[i];

			if g overlaps overlap_geom and !(g touches overlap_geom) {
				if !increase_index {
					increase_index <- true;
					geoms_to_shift <+ nil;
					touching_points <+ g.points; // add points of this segment
				}
				geoms_to_shift[my_index] <- geoms_to_shift[my_index] + g;
				touching_points[length(touching_points)-1][1] <- g.points[1]; // update the end point
			} else {
				if increase_index {
					my_index <- my_index + 1;
					increase_index <- false;
				}
				geoms_to_keep <+ g;
			}
		}

		// detect the position of the line to shift according to the overlapping line
		int shift_direction <- DIRECTION_OUTER;
		if !empty(geoms_to_keep) {
			point long_keep <- centroid(geoms_to_keep with_max_of (each.perimeter));
			point closer <- centroid(to_segments(overlap_geom) with_min_of (centroid(each) distance_to long_keep));
			
			/*g1 <- long_keep;
			g2 <- closer;
			write "long_keep " + long_keep;
			write "closer " +  closer;
			*/
			if long_keep.x > closer.x or long_keep.y < closer.y{
				shift_direction <- DIRECTION_INNER;
			}
		}
		
		write "shift_position " + shift_direction;

		// explore geometry segments to shift
		if !empty(geoms_to_shift) {
		
			loop i from: 0 to: length(geoms_to_shift)-1 {
				shifted_geoms <+ nil;
				
				geometry g_to_shift <- geoms_to_shift[i];			
				geometry g_buffered <- g_to_shift + SHIFT_DISTANCE; // create a shifted buffer
				list<geometry> g_segments <- to_segments(g_buffered);
				list<geometry> tmp_geoms <- [nil,nil]; // both sides of the shifted buffer cut in the extremities
				int geom_index <- 0;
				bool change_index <- false;
				
				point p1 <- touching_points[i][0];
				point p2 <- touching_points[i][1];
				
				// remove extreme and head/tail parts
				loop g over: g_segments {
					if g.perimeter <= SHIFT_DISTANCE and (g distance_to p1 <= SHIFT_DISTANCE or g distance_to p2 <= SHIFT_DISTANCE) {
						if change_index {
							geom_index <- geom_index = 0 ? 1 : 0; // switch to the other side
							change_index <- false;
						}
					} else {
						tmp_geoms[geom_index] <- tmp_geoms[geom_index] + g;
						change_index <- true;
					}	
				}
				
				geometry result_geom;
				point cc <- centroid(g_to_shift); g1 <- cc;
				point c0 <- centroid(tmp_geoms[0]); g2<-c0;
				
				if shift_direction = DIRECTION_OUTER {
					result_geom <- c0.x > cc.x or c0.y < cc.y ? tmp_geoms[0] : tmp_geoms[1];
				} else {
					result_geom <- c0.x > cc.x or c0.y < cc.y ? tmp_geoms[1] : tmp_geoms[0];
				}
				
				//if centroid(geom) < centroid(overlap(geom))
				
				/*int pos <- 1;
				if !empty(geoms_to_keep) {
					pos <- world.line_position (overlap_geom, geometry(geoms_to_keep));
				}
				write "-------pos pos "+pos;
				write g_to_shift.perimeter with_precision 2;
				float coscos <- cos(p1 towards p2);
				float sinsin <- sin(p1 towards p2);
				write "cos " + coscos;
				write "sin " + sinsin;
				
				write "centroid xx " + centroid(g_to_shift).x with_precision 2 + " yy " + centroid(g_to_shift).x with_precision 2;
				write "tmp_geoms0 xx " + centroid(tmp_geoms[0]).x with_precision 2 + " yy " + centroid(tmp_geoms[0]).y with_precision 2;
				write "tmp_geoms1 xx " + centroid(tmp_geoms[1]).x with_precision 2 + " yy " + centroid(tmp_geoms[1]).y with_precision 2; 
				
				if coscos >= 0 {
					if sinsin >= 0 {
						result_geom <- pos = POSITION_OUTER ? 
									tmp_geoms first_with (centroid(each).x <  centroid(g_to_shift).x) :
									tmp_geoms first_with (centroid(each).x >= centroid(g_to_shift).x);
					} else {
						result_geom <- pos = POSITION_OUTER ? 
									tmp_geoms first_with (centroid(each).x >=  centroid(g_to_shift).x) :
									tmp_geoms first_with (centroid(each).x < centroid(g_to_shift).x);
					}
				} else {
					if sinsin >= 0 {
						result_geom <- pos = POSITION_OUTER ? 
									tmp_geoms first_with (centroid(each).x >=  centroid(g_to_shift).x) :
									tmp_geoms first_with (centroid(each).x < centroid(g_to_shift).x);
					} else {
						result_geom <- pos = POSITION_OUTER ? 
									tmp_geoms first_with (centroid(each).x >=  centroid(g_to_shift).x) :
									tmp_geoms first_with (centroid(each).x < centroid(g_to_shift).x);
					}
				}
				
				// compare both sides of the result geometry and get one
				/*list<geometry> to_explore <- to_segments(tmp_geoms[0]);
				list<geometry> to_compare <- to_segments(tmp_geoms[1]);
								
				if length(to_explore) > length(to_compare) { // to explore the smallest list
					to_explore <- to_segments(tmp_geoms[1]);
					to_compare <- to_segments(tmp_geoms[0]);
				}
	
				bool isAbove <- true;
				// get the side above the line to shift
				loop sg over: to_explore {
					float xc <- centroid(sg).x;
					float yc <- centroid(sg).y;
					write cos(sg.points[0] towards sg.points[1]);
					if !empty(to_compare where (centroid(each).x >= xc or centroid(each).y >= yc)) {
						isAbove <- false;
						break;
					}
				}

				// return the above or below side dependeing on the user param
				
	 			if isAbove {
	 				result_geom <- return_above ? geometry(to_explore) : geometry(to_compare);
	 			} else {
	 				result_geom <- return_above ? geometry(to_compare) : geometry(to_explore);
	 			}*/
	 			

	 			
	 			// link the shifted geometry with original geometry by two lines
	 			if result_geom != nil {
		 			list<geometry> mysegs <- to_segments(result_geom);
		 			point pstart <- first(mysegs).points[0];
		 			point pend <- last(mysegs).points[1];
		 			
		 			//result_geom <- line(pstart, [p1,p2] closest_to pstart) + result_geom + line(pend, [p1,p2] closest_to pend);
					shifted_geoms[i] <- result_geom + geometry(geoms_to_keep);	
				} else {
					shifted_geoms[i] <- geometry(geoms_to_keep);
				}
				
			}
			return geometry(shifted_geoms);
		} else {
			return geometry(geoms_to_keep);
		}
	}
	
	// return position of geom_compare par rapport a geom (inner or outer)
	int line_position (geometry geom, geometry geom_compare) {
		geometry myg <- to_segments(geom) first_with (each.perimeter >= 10#m);
		point pc <- centroid(myg);
		geometry otherg <- to_segments(geom_compare) with_min_of (centroid(each) distance_to pc);
		
		if pc >= centroid(otherg) {
			return DIRECTION_INNER;
		} else {
			return DIRECTION_OUTER;
		}	
	}
}

species dummy_geom {
	int varint0; 
	int varint1;
	int varint2;
	int varint3;
	string varstr0;
	string varstr1;
	string varstr2;
}

species BusLine schedules: [] {
	string bl_name;
	
	geometry bl_outgoing_geom;
	geometry bl_return_geom;
		
	map<BusStop,point> bl_outgoing_bs <- [];	
	map<BusStop,point> bl_return_bs <- [];	
	
	rgb bl_color <- rnd_color(254);	
	
	aspect default {
		
		/*loop bs over: bl_outgoing_bs.keys {
			draw square(20#meter) color: #black at: bl_outgoing_bs at bs;
			draw square(10#meter) color: bl_color at: bl_outgoing_bs at bs;	
		}
		
		loop bs over: bl_return_bs.keys { TODO
			draw square(20#meter) color: #black at: bl_return_bs at bs;
			draw square(10#meter) color: bl_color at: bl_return_bs at bs;	
		}*/
	}
}

species BusStop schedules: [] {
	int bs_id;
	string bs_name;
	PDUZone bs_zone;
}

species TaxiLine schedules: [] {
	string tl_id;
	string tl_name;
	TaxiStation tl_start_ts;
	TaxiStation tl_end_ts;	
	
	geometry tl_outgoing_geom;
	geometry tl_return_geom;
	
	rgb tl_color <- rnd_color(254);	
	
	aspect default {
		//draw (shape+3#meter) color: tl_color;
		//draw (shape)/*+1#meter)*/ color: #black;
		draw tl_outgoing_geom color: #red;
		draw tl_return_geom color: #blue;
	}
}

species TaxiStation schedules: [] {
	int ts_id;
	string ts_name;
	
	aspect default {
		draw circle(20#m) color: #white border: #black;
		draw circle(10#m) color: #gamablue border: #black;
		draw ts_name color: #gamablue font:font("Arial",int(1#m),#bold) at: location+{20#m,10#m};
	}
}

species PDUZone schedules: [] {
	int pduz_code;
	string pduz_name;
	
	aspect default {
		draw shape color: #whitesmoke border: #lightgray;
	}
}

experiment VisualNetwork type: gui {
	output {
		
		/*display Region type: opengl background: #white {
			
			species PDUZone;
			//species BusLine;
		}*/
		
		
		display City type: opengl background: #white {
			//camera 'default' location: {76712.1365,71872.4373,24002.274} target: {76712.1365,71872.0184,0.0};
				
			//species PDUZone refresh: false;
			//species BusLine refresh: false;
			species TaxiLine refresh: false;
			//species TaxiStation refresh: false;
			
			
			graphics gg {
				draw circle(10#m) at:g1 color: #darkgreen;
				draw circle(10#m) at:g2 color: #purple;
			}
		}
		
	}
}
