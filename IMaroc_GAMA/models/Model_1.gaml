/**
* Name: Import Roads
* Author:  Arnaud Grignard
* Description: Model which shows how to import a Shapefile in GAMA and use it to create Agents.
* Tags:  load_file, shapefile, gis
*/
model simpleShapefileLoading



global {	
	shape_file marrakesh0_shape_file <- shape_file("../includes/gis/administrative/marrakesh.shp");
	shape_file zonage_pdu0_shape_file <- shape_file("../includes/gis/PDU zoning/zonage_pdu.shp");
	shape_file kech_roads0_shape_file <- shape_file("../includes/gis/roads/kech_roads.shp");
	

	csv_file ODMatrix0_csv_file <- csv_file("../includes/mobility/ODMatrix.csv");
	list<rgb> list_of_color <- list_with(27,rnd_color(255));

	//definition of the geometry of the world agent (environment) as the envelope of the shapefile
	geometry shape <- envelope(marrakesh0_shape_file);
	
	int max_weight;
	int weight_threshold<-10;
	
	init {
		//creation of the building agents from the shapefile: the height and type attributes of the building agents are initialized according to the HEIGHT and NATURE attributes of the shapefile
		create zone from: zonage_pdu0_shape_file with:[id::int(get("id")),pop::int(get("pop2008")), type::string(get("NATURE"))];
		create road from: kech_roads0_shape_file;
		//convert the file into a matrix
		matrix data <- matrix(ODMatrix0_csv_file);
		loop i from: 1 to: data.rows -1{
			loop j from: 0 to: data.columns -1{
				create link{	
					origin <- first(zone where (each.id=i));
					destination <- first(zone where (each.id=j));
					weight <- int(data[j,i]);
				}
			}	
		}	
		max_weight <- max(link collect each.weight );
	}
}

species link{
	zone origin;
	zone destination;
	int weight;
	
	aspect default{
		//draw line(origin.location,destination.location) end_arrow: 10  width:2 color:list_of_color[origin.id];
		draw curve(origin.location,destination.location,0.5,20, 0.8,90) end_arrow: 100  width:(weight/max_weight)*100 color:list_of_color[origin.id];
	}
}

species zone {
	int id;
	int pop;
	string type;
	rgb color;
	
	aspect pop {
		draw shape depth:pop/100 color: blend(#gamared,#white,pop/140000) border:blend(#gamared,#white,pop/140000) width:3;
		draw string(pop) at:{location.x,location.y,(pop/100)*1.1} color: #black font: font("Helvetica", 10 );
	}	
	aspect od {
		draw shape color: blend(#gamared,#white,pop/140000) border:blend(#gamared,#white,pop/140000) width:3;
		ask (link where (each.origin.id=id)){
			if(weight>weight_threshold){
			  //draw curve(origin.location,destination.location,0.5,20, 0.8,90) end_arrow: 100  width:(weight/max_weight)*100 color:list_of_color[origin.id];
			  draw curve(origin.location,destination.location,weight/max_weight,20, 0.8,90) end_arrow: 100  width:(weight/max_weight)*50 color:blend(#gamared,#black,weight/max_weight);	
			}
		}
	}	
}

species road{
	aspect default {
		draw shape color:#gray border:#black width:2;
	}
}




experiment IMaroc type: gui {
	output {
		display Population type: 3d axes:true background:rgb(0,50,0){
			graphics "info"{ 
				draw "I-MAROC" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
				draw "Population: "  + sum(zone collect each.pop) at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
			}
			species zone aspect:pop position:{0,0,-0.01} transparency:0.25;
			species road;
		}
		display OD type: 3d axes:true background:rgb(0,50,0){
			graphics "info"{ 
				draw "I-MAROC" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
				draw "Origin Destination: "  + sum(link collect each.weight) + " trips" at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
			}
			species zone aspect:od position:{0,0,-0.01};
			species road;
			//species link;
		}
	}
}

