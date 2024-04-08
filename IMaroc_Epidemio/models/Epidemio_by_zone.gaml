/**
* Name: Import Roads
* Author:  Arnaud Grignard
* Description: Model which shows how to import a Shapefile in GAMA and use it to create Agents.
* Tags:  load_file, shapefile, gis
*/
model simpleShapefileLoading



global {	
	
	shape_file zonage_pdu0_shape_file <- shape_file("../includes/gis/PDU_zoning/zonage_pdu.shp");
	csv_file ODMatrix <- csv_file("../includes/mobility/PublicTrans_OD_Matrix.csv");
//	map<int,rgb> color_per_mode <- [0::rgb(52,152,219), 1::rgb(192,57,43), 2::rgb(161,196,90), 3::#magenta,4::#cyan];	
//	list<rgb> list_of_color <- list_with(27,rnd_color(255));
	rgb background<-#black;

	//definition of the geometry of the world agent (environment) as the envelope of the shapefile
	geometry shape <- envelope(zonage_pdu0_shape_file);
	list<string> central_districts <- ["Medina","Gueliz_Hiv"];
	
	float max_weight;
	int weight_threshold<-1500;
	int max_pop_per_district_2008;
	int max_pop_per_district_2023;
	
	int trip_scale <- 1;
	float central_district_travel_weight <- 0.7;
	
	float infection_rate <- 0.4; 
	float incubation_to_infection_rate <- 0.2;
	float recovery_rate <- 0.13;
	
	float city_S -> district sum_of(each.S) + travelers sum_of(each.S);
	float city_E -> district sum_of(each.E) + travelers sum_of(each.E);
	float city_I -> district sum_of(each.I) + travelers sum_of(each.I);
	float city_R -> district sum_of(each.R) + travelers sum_of(each.R);
	
//	int incubation_cycle_duration <- 6;
//	float infection_cycle_duration <- 10;
	
	init {
		//creation of the district shapefile
		create district from: zonage_pdu0_shape_file with:[id::int(get("id")),pop_2008::int(get("pop2008")),pop::int(get("pop2023")), name::string(get("label")), zone::string(get("agregate"))];
		ask district{
			self.S <- float(self.pop);
		}
		ask one_of(district){
			I <- 1.0;
			write self.name;
		}
		create district_transparency;
		
		//convert the file into a matrix
		int totalTrips;
		matrix data <- matrix(ODMatrix);
		loop i from: 0 to: data.rows -1{
			loop j from: 0 to: data.columns -1{
				create travelers{	
					origin <- first(district where (each.id=i+1));
					destination <- first(district where (each.id=j+1));
					S <- float(data[j,i])*trip_scale;
					origin.S <- origin.S - S;
//					write "data ("+i+","+j+") "+origin.name;
					if (origin.name in central_districts) and !(destination.name in central_districts){
						S <- float(round(S*(1-central_district_travel_weight)));
					}
					if !(origin.name in central_districts) and (destination.name in central_districts){
						S <- float(round(S*central_district_travel_weight));
					}
				}
				
			}	
		}		
		max_weight <- max(travelers collect each.nb_travelers);
//		write max_weight;
		max_pop_per_district_2008<-max(district collect each.pop_2008);
		max_pop_per_district_2023<-max(district collect each.pop);
	}
}

species travelers{
	district origin;
	district destination;
//	int weight;
	
	float S;
	float E;
	float I;
	float Q;
	float R;
	
	float nb_travelers -> S+E+I+R;
	
	aspect default{
		if (E+I>50){
			rgb lineColor <- blend(#gamared,#white,10*(E+I)/(S+E+I+R));
			draw curve(origin.location,destination.location,0.5,20, 0.8,90) end_arrow: 100  width:(nb_travelers/max_weight)*5 color:lineColor;		
		}
//		if (nb_travelers > weight_threshold*trip_scale){
//			rgb lineColor <- blend(#gamared,#white,10*(E+I)/(S+E+I+R));
//			draw curve(origin.location,destination.location,0.5,20, 0.8,90) end_arrow: 100  width:(nb_travelers/max_weight)*10 color:lineColor;		
//		}
	}
}

species district_transparency{
	
	aspect default{
		ask district{
			if E+I > self.pop*0.01{
				rgb colorInfection <- #orange;
				if E+I > self.pop*0.03 {
					colorInfection <- #red;
				}
				draw shape depth:(E+I)/100 color: colorInfection border:colorInfection width:1;
			}
		}
		ask district{
			draw shape+0.1 depth:pop/100 color: rgb(255,255,255,0.25) border:rgb(255,255,255,0.75) width:1;
		}
	}
}

species district {
	int id;
	string zone;
	string name;
	int pop_2008;
	int pop;
	rgb color;
	float S <-0.0;
	float E <-0.0;
	float I <-0.0;
	float R <-0.0;
	float nb_infections <- 0.0;
	
	float test_pop -> S+E+I+R;
	
	reflex infection when: (pop != 0){
		list<travelers> travelers_at_district;
		if (mod(cycle,2) = 0){
			travelers_at_district <- travelers where(each.destination = self);
		}else{
			travelers_at_district <- travelers where(each.origin = self);
		}
		float total_S <- S + sum(travelers_at_district collect(each.S));
		float total_E <- E + sum(travelers_at_district collect(each.E));
		float total_I <- I + sum(travelers_at_district collect(each.I));
		float total_R <- R + sum(travelers_at_district collect(each.R));
//		int nb_infections <- int(ceil(infection_rate * I * S/pop));
//		int to_infected <- int(ceil(incubation_to_infection_rate*E));
//		int to_recovered <- int(ceil(recovery_rate*I));
		nb_infections <- infection_rate * total_I * total_S/pop;
		float to_infected <- incubation_to_infection_rate*total_E;
		float to_recovered <- recovery_rate*total_I;
		
		R <- max(0,R + (total_I>0?to_recovered*I/total_I:0));	
		I <- max(0,I + (total_E>0?to_infected *E/total_E:0) - (total_I>0?to_recovered*I/total_I:0));
		E <- max(0,E + (total_S>0?nb_infections* S/total_S:0) - (total_E>0?to_infected *E/total_E:0));	
		S <- max(0,S - (total_S>0?nb_infections * S/total_S:0));
		
		ask travelers_at_district{
			self.R <- max(0,self.R + (total_I>0?to_recovered*self.I/total_I:0));	
			self.I <- max(0,self.I + (total_E>0?to_infected *self.E/total_E:0) - (total_I>0?to_recovered*self.I/total_I:0));
			self.E <- max(0,self.E + (total_S>0?myself.nb_infections* self.S/total_S:0) - (total_E>0?to_infected *self.E/total_E:0));
			self.S <- max(0,self.S - (total_S>0?myself.nb_infections * self.S/total_S:0));
		}
	}
	
	
	aspect base{
		if zone in central_districts{
			draw shape color:#grey border:#black;
		}else{
			draw shape color:#white border:#black;
		}
		loop i from:1 to: floor(nb_infections) step: 1 {
			draw circle(40) color: #red at: any_location_in(self.shape);
		}
		draw name at:{location.x,location.y,10} anchor: #center color: #black font: font("Helvetica", 10 );
	}
	
	aspect pop {
//		if E+I > 1{
//			draw shape depth:(E+I)/100 color: #red border:#red width:1;
//		}
//		draw shape+0.1 depth:pop/100 color: rgb(255,255,255,0.25) border:rgb(255,255,255,0.75) width:1;
//			
		draw string(int(E+I)) at:{location.x,location.y,(pop/100)*1.1} color: #black font: font("Helvetica", 10 );
//		draw shape depth:pop/100 color: blend(#gamared,#white,pop/max_pop_per_district_2023) border:blend(#gamared,#white,pop/max_pop_per_district_2023) width:3;
//		draw string(pop) at:{location.x,location.y,(pop/100)*1.1} color: #black font: font("Helvetica", 10 );

	}
	aspect pop_2008 {
		draw shape depth:pop_2008/100 color: blend(#gamared,#white,pop_2008/max_pop_per_district_2008) border:blend(#gamared,#white,pop_2008/max_pop_per_district_2008) width:3;
		draw string(pop_2008) at:{location.x,location.y,(pop_2008/100)*1.1} color: #black font: font("Helvetica", 10 );
	}		
	aspect od {
		draw shape color: blend(#gamared,#white,pop_2008/140000) border:blend(#gamared,#white,pop_2008/140000) width:3;
//		ask (link where (each.origin.id=id)){
//			if(weight>weight_threshold){
//			  //draw curve(origin.location,destination.location,0.5,20, 0.8,90) end_arrow: 100  width:(weight/max_weight)*100 color:list_of_color[origin.id];
//			  draw curve(origin.location,destination.location,weight/max_weight*2,100, 0.8,90) end_arrow: 100  width:(weight/max_weight)*50 color:blend(#gamared,#black,weight/max_weight);	
//			}
//		}
	}	
}




//species zone{
//	int id;
//	int pop_2014;
//	int pop_2023;
//	int pop_2030;
//	aspect pop_2014{
//		draw shape depth:pop_2014/100 color: blend(#gamared,#white,pop_2014/max_pop_per_zone_2014);
//		draw string(pop_2014) at:{location.x,location.y,(pop_2014/100)*1.1} color: #black font: font("Helvetica", 10 );
//	}
//	
//	aspect pop_2023{
//		draw shape depth:pop_2023/100 color: blend(#gamared,#white,pop_2023/max_pop_per_zone_2023);
//		draw string(pop_2023) at:{location.x,location.y,(pop_2023/100)*1.1} color: #black font: font("Helvetica", 10 );
//	}
//	
//	aspect pop_2030{
//		draw shape depth:pop_2030/100 color: blend(#gamared,#white,pop_2030/max_pop_per_zone_2030);
//		draw string(pop_2030) at:{location.x,location.y,(pop_2030/100)*1.1} color: #black font: font("Helvetica", 10 );
//	}
//}


experiment IMaroc_population type: gui {
	output {
//		display Population_2008 type: 3d axes:true background:rgb(0,50,0){
//			graphics "info"{ 
//				draw "I-MAROC" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
//				draw "Population (2008): "  + sum(district collect each.pop_2008) at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
//			}
//			species district aspect:pop_2008 position:{0,0,-0.01} transparency:0.25;
//		}
		
		display Population type: 3d axes:false toolbar:false background:rgb(0,50,0){
			graphics "info"{ 
				
				draw "I-MAROC" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
				draw "Population (2023): "  + sum(district collect each.pop) at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
			}
			species district aspect:pop position:{0,0,-0.01};
			species district_transparency;
		}
		
		display Mobility type: 3d axes:false toolbar:false background:rgb(0,50,0){
			graphics "info"{ 
				draw "I-MAROC" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
				draw "Population (2023): "  + sum(district collect each.pop) at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
			}
			species district aspect:base position:{0,0,-0.01} transparency:0.25;
			species travelers;
		}
		display "Epidemics" toolbar:false background:rgb(0,50,0){
		    chart "Epidemics" type: series  background:rgb(0,50,0) color:#white tick_line_color: #white{
//			data "Infected" value: city_I+city_S+city_E+city_R color: #red;
				data "Prevalence" value: city_I color: #red marker: false;
				data "Total recoveries" value: city_R color: #orange marker: false;
		    }
		}
	}
}

//experiment IMaroc_Mobility type: gui {
//	output {
//		display OD type: 3d axes:true background:background toolbar:false{
//			graphics "info"{ 
//				draw "I-MAROC" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
//				draw "Origin Destination: "  + sum(link collect each.weight) + " trips" at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
//			}
//			species district aspect:base position:{0,0,-0.01};
//			species link;
//		}
//		display OD_pedestrian type: 3d axes:true background:background toolbar:false{
//			graphics "info"{ 
//				draw "Pedestrian: "+ sum(link where (each.mode=0) collect each.weight) + " trips" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
//			}
//			species district aspect:base position:{0,0,-0.01};
//			species link aspect:pedestrian;
//		}
//		display OD_bus type: 3d axes:true background:background toolbar:false{
//			graphics "info"{ 
//				draw "Bus: "+ sum(link where (each.mode=1) collect each.weight) + " trips"  at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
//			}
//			species district aspect:base position:{0,0,-0.01};
//			species link aspect:bus;
//		} 
//		display OD_moped type: 3d axes:true background:background toolbar:false{
//			graphics "info"{ 
//				draw "Moped: " + sum(link where (each.mode=2) collect each.weight) + " trips" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
//			}
//			species district aspect:base position:{0,0,-0.01};
//			species link aspect:moped;
//		}
//		display OD_car type: 3d axes:true background:background toolbar:false{
//			graphics "info"{ 
//				draw "Car: "+ sum(link where (each.mode=3) collect each.weight) + " trips"  at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
//			}
//			species district aspect:base position:{0,0,-0.01};
//			species link aspect:car;
//		}
//		display OD_public type: 3d axes:true background:background toolbar:false{
//			graphics "info"{ 
//				draw "Public: " + sum(link where (each.mode=4) collect each.weight) + " trips" at:{0,-1500} color: #white font: font("Helvetica", 20 , #bold);
//			}
//			species district aspect:base position:{0,0,-0.01};
//			species link aspect:public;
//		}
//	}
//}
//
