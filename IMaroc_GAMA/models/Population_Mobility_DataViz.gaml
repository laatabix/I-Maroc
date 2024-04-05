/**
* Name: Import Roads
* Author:  Arnaud Grignard
* Description: Model which shows how to import a Shapefile in GAMA and use it to create Agents.
* Tags:  load_file, shapefile, gis
*/
model simpleShapefileLoading



global {	
	shape_file marrakesh0_shape_file <- shape_file("../includes/gis/administrative/marrakesh_districts.shp");
	shape_file zonage_pdu0_shape_file <- shape_file("../includes/gis/PDU_zoning/zonage_pdu.shp");
	shape_file kech_roads0_shape_file <- shape_file("../includes/gis/roads/kech_roads.shp");
	

	
	list<csv_file> ODMatrixS <- [csv_file("../includes/mobility/Pedestrian_OD_Matrix.csv"), csv_file("../includes/mobility/Bus_OD_Matrix.csv"),csv_file("../includes/mobility/Moped_OD_Matrix.csv"),csv_file("../includes/mobility/Car_OD_Matrix.csv"),csv_file("../includes/mobility/PublicTrans_OD_Matrix.csv")];
	map<int,rgb> color_per_mode <- [0::rgb(52,152,219), 1::rgb(192,57,43), 2::rgb(161,196,90), 3::#magenta,4::#cyan];
	
	list<rgb> list_of_color <- list_with(27,rnd_color(255));
	rgb background<-#black;

	//definition of the geometry of the world agent (environment) as the envelope of the shapefile
	geometry shape <- envelope(marrakesh0_shape_file);
	
	int max_weight;
	int weight_threshold<-10;
	int max_pop_per_district_2008;
	int max_pop_per_district_2023;
	int max_pop_per_zone_2014;
	int max_pop_per_zone_2023;
	int max_pop_per_zone_2030;
	
	init {
		//creation of the building agents from the shapefile: the height and type attributes of the building agents are initialized according to the HEIGHT and NATURE attributes of the shapefile
		create zone from: marrakesh0_shape_file with:[id::int(get("id")),pop_2014::int(get("pop2014")),pop_2023::int(get("pop2023")),pop_2030::int(get("pop2030"))];	
		create district from: zonage_pdu0_shape_file with:[id::int(get("id")),pop_2008::int(get("pop2008")),pop::int(get("pop2023")), type::string(get("NATURE"))];
		create road from: kech_roads0_shape_file;
		//convert the file into a matrix
		int curODID<-0;
		loop o over:ODMatrixS{
		  matrix data <- matrix(o);
			loop i from: 1 to: data.rows -1{
				loop j from: 0 to: data.columns -1{
					create link{	
						origin <- first(district where (each.id=i));
						destination <- first(district where (each.id=j));
						weight <- int(data[j,i]);
						mode<-curODID;
					}
				}	
			}	
		  curODID<-curODID+1;
		}
				
		max_weight <- max(link collect each.weight );
		max_pop_per_district_2008<-max(district collect each.pop_2008);
		max_pop_per_district_2023<-max(district collect each.pop);
		max_pop_per_zone_2014<-max(zone collect each.pop_2014);
		max_pop_per_zone_2023<-max(zone collect each.pop_2023);
		max_pop_per_zone_2030<-max(zone collect each.pop_2030);
	}
}

species link{
	district origin;
	district destination;
	int weight;
	int mode;
	
	aspect default{
		draw curve(origin.location,destination.location,0.5,20, 0.8,90) end_arrow: 100  width:(weight/max_weight)*100 color:color_per_mode[mode];
	}
	aspect pedestrian{
		if(mode=0){
			draw curve(origin.location,destination.location,0.5,20, 0.8,90) end_arrow: 100  width:(weight/max_weight)*100 color:color_per_mode[mode];
		}
	}
	aspect bus{
		if(mode=1){
			draw curve(origin.location,destination.location,0.5,20, 0.8,90) end_arrow: 100  width:(weight/max_weight)*100 color:color_per_mode[mode];
		}
	}
	aspect moped{
		if(mode=2){
			draw curve(origin.location,destination.location,0.5,20, 0.8,90) end_arrow: 100  width:(weight/max_weight)*100 color:color_per_mode[mode];
		}
	}
	aspect car{
		if(mode=3){
			draw curve(origin.location,destination.location,0.5,20, 0.8,90) end_arrow: 100  width:(weight/max_weight)*100 color:color_per_mode[mode];
		}
	}
	aspect public{
		if(mode=4){
			draw curve(origin.location,destination.location,0.5,20, 0.8,90) end_arrow: 100  width:(weight/max_weight)*100 color:color_per_mode[mode];
		}
	}
}

species district {
	int id;
	int pop_2008;
	int pop;
	string type;
	rgb color;
	
	aspect base{
		draw shape color:#white border:#black;
	}
	
	aspect pop {
		draw shape depth:pop/100 color: blend(#gamared,#white,pop/max_pop_per_district_2023) border:blend(#gamared,#white,pop/max_pop_per_district_2023) width:3;
		draw string(pop) at:{location.x,location.y,(pop/100)*1.1} color: #black font: font("Helvetica", 10 );
	}
	aspect pop_2008 {
		draw shape depth:pop_2008/100 color: blend(#gamared,#white,pop_2008/max_pop_per_district_2008) border:blend(#gamared,#white,pop_2008/max_pop_per_district_2008) width:3;
		draw string(pop_2008) at:{location.x,location.y,(pop_2008/100)*1.1} color: #black font: font("Helvetica", 10 );
	}		
	aspect od {
		draw shape color: blend(#gamared,#white,pop_2008/140000) border:blend(#gamared,#white,pop_2008/140000) width:3;
		ask (link where (each.origin.id=id)){
			if(weight>weight_threshold){
			  //draw curve(origin.location,destination.location,0.5,20, 0.8,90) end_arrow: 100  width:(weight/max_weight)*100 color:list_of_color[origin.id];
			  draw curve(origin.location,destination.location,weight/max_weight*2,100, 0.8,90) end_arrow: 100  width:(weight/max_weight)*50 color:blend(#gamared,#black,weight/max_weight);	
			}
		}
	}	
}


species road{
	aspect default {
		draw shape color:#gray border:#black width:2;
	}
}

species zone{
	int id;
	int pop_2014;
	int pop_2023;
	int pop_2030;
	aspect pop_2014{
		draw shape depth:pop_2014/100 color: blend(#gamared,#white,pop_2014/max_pop_per_zone_2014);
		draw string(pop_2014) at:{location.x,location.y,(pop_2014/100)*1.1} color: #black font: font("Helvetica", 10 );
	}
	
	aspect pop_2023{
		draw shape depth:pop_2023/100 color: blend(#gamared,#white,pop_2023/max_pop_per_zone_2023);
		draw string(pop_2023) at:{location.x,location.y,(pop_2023/100)*1.1} color: #black font: font("Helvetica", 10 );
	}
	
	aspect pop_2030{
		draw shape depth:pop_2030/100 color: blend(#gamared,#white,pop_2030/max_pop_per_zone_2030);
		draw string(pop_2030) at:{location.x,location.y,(pop_2030/100)*1.1} color: #black font: font("Helvetica", 10 );
	}
}


experiment IMaroc_population type: gui {
	output {
		
		display Population_2014 type: 3d axes:true background:rgb(0,50,0){
			graphics "info"{ 
				draw "I-MAROC" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
				draw "Population 2014 (zone): "  + sum(zone collect each.pop_2014) at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
			}
			species zone aspect:pop_2014 position:{0,0,-0.01};
		}
		
		display Population_2023 type: 3d axes:true background:rgb(0,50,0){
			graphics "info"{ 
				draw "I-MAROC" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
				draw "Population 2023 (zone): "  + sum(zone collect each.pop_2023) at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
			}
			species zone aspect:pop_2023 position:{0,0,-0.01};
		}
		
		display Population_2030 type: 3d axes:true background:rgb(0,50,0){
			graphics "info"{ 
				draw "I-MAROC" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
				draw "Population 2030 (zone): "  + sum(zone collect each.pop_2030) at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
			}
			species zone aspect:pop_2030 position:{0,0,-0.01};
		}
		
		
		display Population_2008 type: 3d axes:true background:rgb(0,50,0){
			graphics "info"{ 
				draw "I-MAROC" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
				draw "Population (2008): "  + sum(district collect each.pop_2008) at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
			}
			species district aspect:pop_2008 position:{0,0,-0.01} transparency:0.25;
			species road;
		}
		
		
		display Population type: 3d axes:true background:rgb(0,50,0){
			graphics "info"{ 
				draw "I-MAROC" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
				draw "Population (2023): "  + sum(district collect each.pop) at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
			}
			species district aspect:pop position:{0,0,-0.01} transparency:0.25;
			species road;
		}
		display OD type: 3d axes:true background:#gamablue{
			graphics "info"{ 
				draw "I-MAROC" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
				draw "Origin Destination: "  + sum(link collect each.weight) + " trips" at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
			}
			species district aspect:od position:{0,0,-0.01};
			species road;
			//species link;
		}
	}
}

experiment IMaroc_Mobility type: gui {
	output {
		display OD type: 3d axes:true background:background toolbar:false{
			graphics "info"{ 
				draw "I-MAROC" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
				draw "Origin Destination: "  + sum(link collect each.weight) + " trips" at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
			}
			species district aspect:base position:{0,0,-0.01};
			species link;
		}
		display OD_pedestrian type: 3d axes:true background:background toolbar:false{
			graphics "info"{ 
				draw "Pedestrian: "+ sum(link where (each.mode=0) collect each.weight) + " trips" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
			}
			species district aspect:base position:{0,0,-0.01};
			species link aspect:pedestrian;
		}
		display OD_bus type: 3d axes:true background:background toolbar:false{
			graphics "info"{ 
				draw "Bus: "+ sum(link where (each.mode=1) collect each.weight) + " trips"  at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
			}
			species district aspect:base position:{0,0,-0.01};
			species link aspect:bus;
		} 
		display OD_moped type: 3d axes:true background:background toolbar:false{
			graphics "info"{ 
				draw "Moped: " + sum(link where (each.mode=2) collect each.weight) + " trips" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
			}
			species district aspect:base position:{0,0,-0.01};
			species link aspect:moped;
		}
		display OD_car type: 3d axes:true background:background toolbar:false{
			graphics "info"{ 
				draw "Car: "+ sum(link where (each.mode=3) collect each.weight) + " trips"  at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
			}
			species district aspect:base position:{0,0,-0.01};
			species link aspect:car;
		}
		display OD_public type: 3d axes:true background:background toolbar:false{
			graphics "info"{ 
				draw "Public: " + sum(link where (each.mode=4) collect each.weight) + " trips" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
			}
			species district aspect:base position:{0,0,-0.01};
			species link aspect:public;
		}
	}
}

