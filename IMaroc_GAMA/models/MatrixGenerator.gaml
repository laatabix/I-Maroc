/**
* Name: MatrixGenerator
* Based on the internal skeleton template. 
* Author: Laatabi
* Tags: 
*/

model MatrixGenerator

global {

	shape_file pdu_shape_file <- shape_file("../includes/gis/PDU zoning/zonage_pdu.shp");
	shape_file district_shape_file <- shape_file("../includes/gis/administrative/marrakesh_districts.shp");
	
	// data in these lists is in the same order
	list<string> aggregates_of_zones <- ["Medina","Daoudiate","Gueliz_Hiv","SYBA","Azli","Massira","Mhamid","Other"];
	list<int> agg_percent_pedestrian_moves <- [56,45,50,56,63,63,64,64];
	list<int> agg_percent_car_moves <- [14,28,26,14,14,14,12,12];
	list<int> agg_percent_moped_moves <- [24,24,17,24,18,18,21,21];
	list<int> agg_percent_public_trans_moves <- [6,3,7,6,3,3,3,3]; // public transport
	
	matrix agreg_bus_trips_matrix2008 <- matrix(csv_file("../includes/mobility/AggreagteODBusTrips2008.csv"));
	
	init {
		
		create district from: district_shape_file with:[id::int(get("ID")),name::get("NAME"),
			pop2104::int(get("pop2014")),pop2023::int(get("pop2023")),pop2030::int(get("pop2030"))];
		
		loop agg over: aggregates_of_zones {
			create aggregate {
				id <- int(self);
				name <- agg;
				percent_pedestrians <- agg_percent_pedestrian_moves[id];
				percent_cars <- agg_percent_car_moves[id];
				percent_mopeds <- agg_percent_moped_moves[id];
				percent_public_trans <- agg_percent_public_trans_moves[id];
			}
		}
		
		create zone_pdu from: pdu_shape_file with:[id::int(get("id")),name::get("label"),
			pop2008::int(get("pop2008")),pop2023::int(get("pop2023")),total_moves::int(get("total_move")),
			my_aggregate::aggregate first_with(each.name = get("agregate")),
			my_district::district first_with(each.name = get("district"))] {
				my_district.dis_zones <+ self;
			}
		
		loop i from: 0 to: agreg_bus_trips_matrix2008.rows -1 {
			aggregate ag <- aggregate first_with(each.id = i);
			loop j from: 0 to: length(aggregates_of_zones) - 1 {
				ag.ag_generated_bus_trips2008 <+ aggregate first_with(each.id = j)::int(agreg_bus_trips_matrix2008[j,i]);
			}
			ag.ag_zones <<+ zone_pdu where (each.my_aggregate = ag);
		}
		
		// generate OD matrices of zones
		matrix zones_bus_OD_matrix <- {27,27} matrix_with 0;
		
		// OD is given by agregates, so loop over ageragtes of zones
		loop ag1 over: aggregate {
			int ag1_pop2008 <- ag1.ag_zones sum_of(each.pop2008);

			// for each agreagte, we get is OD matrix towards (itself and) other agreagates
			loop ag2 over: ag1.ag_generated_bus_trips2008.keys {
				int ag2_pop2008 <- ag2.ag_zones sum_of(each.pop2008);
				int o_bus_trips <- ag1.ag_generated_bus_trips2008 at ag2;
				
				// get the zones of origin aggragte 
				loop ozone over: ag1.ag_zones {
					int d_bus_trips <- round(o_bus_trips * (ozone.pop2008 / ag1_pop2008));

					// zones of the destination aggreagte
					// distribute the number of bus trip between zones according to the share of 2008pop
					loop dzone over: ag2.ag_zones {
						zones_bus_OD_matrix[dzone.id-1,ozone.id-1] <- round(d_bus_trips * (dzone.pop2008 / ag2_pop2008));
					}
				}
			}
		}
		
		write "OD Matrix of Daily Bus Trips between the 27 Zones : ";
		write zones_bus_OD_matrix;
		write "--------------------*--------------------";
		write "--------------------*--------------------";
		
		// use bus trips OD matrix shares to generate other matrices
		matrix zones_pedestrian_OD_matrix <- {27,27} matrix_with 0;
		matrix zones_car_OD_matrix <- {27,27} matrix_with 0;
		matrix zones_moped_OD_matrix <- {27,27} matrix_with 0;
		matrix zones_publictrans_OD_matrix <- {27,27} matrix_with 0;
		
		loop i from: 0 to: zones_bus_OD_matrix.rows-1 {
			int rowsum <- sum(zones_bus_OD_matrix row_at i);
			if rowsum = 0 {
				continue;
			}
			
			zone_pdu zn <- zone_pdu first_with (each.id = i+1);
			int pedestrians <- round(zn.total_moves * (zn.my_aggregate.percent_pedestrians / 100));
			int bycars <- round(zn.total_moves * (zn.my_aggregate.percent_cars / 100));
			int bymopeds <- round(zn.total_moves * (zn.my_aggregate.percent_mopeds / 100));
			int bypublictrans <- round(zn.total_moves * (zn.my_aggregate.percent_public_trans / 100));
			
			loop j from: 0 to: zones_bus_OD_matrix.columns-1 {
				float aratio <- zones_bus_OD_matrix[j,i] / rowsum;
				zones_pedestrian_OD_matrix[j,i] <- round(pedestrians * aratio);
				zones_car_OD_matrix[j,i] <- round(bycars * aratio);
				zones_moped_OD_matrix[j,i] <- round(bymopeds * aratio);
				zones_publictrans_OD_matrix[j,i] <- round(bypublictrans * aratio);
			}
		}
			
		write "OD Matrix of Daily Pedestrian Trips between the 27 Zones : ";
		write zones_pedestrian_OD_matrix;
		write "--------------------*--------------------";
		write "--------------------*--------------------";
		
		write "OD Matrix of Daily Car Trips between the 27 Zones : ";
		write zones_car_OD_matrix;
		write "--------------------*--------------------";
		write "--------------------*--------------------";
		
		write "OD Matrix of Daily Moped Trips between the 27 Zones : ";
		write zones_moped_OD_matrix;
		write "--------------------*--------------------";
		write "--------------------*--------------------";
		
		write "OD Matrix of Daily PT Trips between the 27 Zones : ";
		write zones_publictrans_OD_matrix;
		write "--------------------*--------------------";
		write "--------------------*--------------------";
		
		
		// savig to files
		save zones_bus_OD_matrix to: "../includes/mobility/Bus_OD_Matrix.csv" header:false format:"csv" rewrite: true;
		save zones_pedestrian_OD_matrix to: "../includes/mobility/Pedestrian_OD_Matrix.csv" header:false format:"csv" rewrite: true;
		save zones_car_OD_matrix to: "../includes/mobility/Car_OD_Matrix.csv" header:false format:"csv" rewrite: true;
		save zones_moped_OD_matrix to: "../includes/mobility/Moped_OD_Matrix.csv" header:false format:"csv" rewrite: true;
		save zones_publictrans_OD_matrix to: "../includes/mobility/PublicTrans_OD_Matrix.csv" header:false format:"csv" rewrite: true;
		
		
		write "saved!";
		
	}
}


species zone_pdu {
	int id;
	string name;
	aggregate my_aggregate;
	district my_district;
	int pop2008;
	int pop2023;
	
	int total_moves;
}

species aggregate {
	int id;
	string name;
	
	map<aggregate,int> ag_generated_bus_trips2008 <- [];
	list<zone_pdu> ag_zones <- [];
	
	int percent_pedestrians;
	int percent_cars;
	int percent_mopeds;
	int percent_public_trans;
}

species district {
	int id;
	string name;
	int pop2104; // censused pop
	int pop2023; // projection
	int pop2030; // projection
	
	list<zone_pdu> dis_zones <- [];
}

experiment MatrixGenerator type: gui {
	/** Insert here the definition of the input and output of the model */
	output {
	}
}
