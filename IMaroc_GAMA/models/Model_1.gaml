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

	//definition of the geometry of the world agent (environment) as the envelope of the shapefile
	geometry shape <- envelope(marrakesh0_shape_file);
	
	init {
		//creation of the building agents from the shapefile: the height and type attributes of the building agents are initialized according to the HEIGHT and NATURE attributes of the shapefile
		create zone from: zonage_pdu0_shape_file with:[pop::int(get("pop2008")), type::string(get("NATURE"))];
		create road from: kech_roads0_shape_file;
	}
}

species zone {
	int pop;
	string type;
	rgb color;
	
	aspect default {
		draw shape depth:pop/100 color: blend(#gamared,#white,pop/140000) border:blend(#gamared,#white,pop/140000) width:3;
		draw string(pop) at:{location.x,location.y,(pop/100)*1.1} color: #black font: font("Helvetica", 10 );
	}	
}

species road{
	aspect default {
		draw shape color: color border:#black width:2;
	}
}

experiment GIS_agentification type: gui {
	output {
		display Population type: 3d axes:true background:#black{
			graphics "info"{ 
				draw "I-MAROC" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
				draw "Population: "  + sum(zone collect each.pop) at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
			}
			species zone position:{0,0,-0.01};
			species road;
		}
	}
}

