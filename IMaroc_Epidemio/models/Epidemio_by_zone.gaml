/**
* Name: MarrakEpidemics
* Author:  Tri Nguyen-Huu
* Description: Model which shows how to import a Shapefile in GAMA and use it to create Agents.
* Tags:  load_file, shapefile, gis
*/
model simpleShapefileLoading



global {	
	
	shape_file zonage_pdu0_shape_file <- shape_file("../includes/gis/PDU_zoning/zonage_pdu.shp");
//	csv_file ODMatrix <- csv_file("../includes/mobility/PublicTrans_OD_Matrix.csv");
	shape_file kech_roads0_shape_file <- shape_file("../includes/gis/roads/kech_roads.shp");
	list<csv_file> ODMatrices <- [csv_file("../includes/mobility/Car_OD_Matrix.csv"),csv_file("../includes/mobility/PublicTrans_OD_Matrix.csv"),csv_file("../includes/mobility/Moped_OD_Matrix.csv"),csv_file("../includes/mobility/Pedestrian_OD_Matrix.csv")];
	list<string> modes <- ['Cars','Public transport','2 wheels','Pedestrians'];
	list<float> modes_weights <- [0.1,0.5,0.05,0.02];

	list<rgb> color_per_mode <- [rgb(231, 76, 60), rgb(52, 152, 219), rgb(243, 156, 18), rgb(46, 204, 113)];
	int nb_transportation_modes <-length(ODMatrices);

//	map<int,rgb> color_per_mode <- [0::rgb(52,152,219), 1::rgb(192,57,43), 2::rgb(161,196,90), 3::#magenta,4::#cyan];	
//	list<rgb> list_of_color <- list_with(27,rnd_color(255));
	rgb background<-#black;

	//definition of the geometry of the world agent (environment) as the envelope of the shapefile
	geometry shape <- envelope(zonage_pdu0_shape_file);
	list<string> central_districts <- ["Medina","Gueliz_Hiv"];
	
	int max_weight;
	int weight_threshold<-1500;
	int link_threshold <- 50;
	int max_pop_per_district_2008;
	int max_pop_per_district_2023;
	
	int focus_half_life <- 3;
	
	int trip_scale <- 1;
	float central_district_travel_weight <- 0.2;
	
	float infection_probability <- 0.04  parameter: true min:0.0 max:3.0 step:0.001 ;
	map<string,float> avg_contacts <- ["day"::20.0,"night"::5.0];
	float incubation_to_infection_rate <- 0.2;
	float recovery_rate <- 0.13;
	float quarantine_rate <- 0.0 parameter: true min:0.0 max:1.0 step:0.001 ;
	
	float R0 <- infection_probability * sqrt(avg_contacts["day"] * avg_contacts["night"]) /(recovery_rate+quarantine_rate);
	
	int city_S -> district sum_of(each.S) + travelers sum_of(each.S);
	int city_E -> district sum_of(each.E) + travelers sum_of(each.E);
	int city_I -> district sum_of(each.I) + travelers sum_of(each.I);
	int city_Q -> district sum_of(each.Q) + travelers sum_of(each.Q);
	int city_R -> district sum_of(each.R) + travelers sum_of(each.R);
	int total_population -> city_S + city_E + city_I + city_Q + city_R;
	
	string moment_of_the_day;
	int current_propagation_step <- 0;
	string start_district_name;
	list<int> modal_part <- list_with(nb_transportation_modes,0);
	
	init {
		create road from: kech_roads0_shape_file;
		//creation of the district shapefile
		create district from: zonage_pdu0_shape_file with:[id::int(get("id")),pop_2008::int(get("pop2008")),pop::int(get("pop2023")), name::string(get("label")), zone::string(get("agregate"))];
		ask district{
			self.S <- self.pop;
		}
		
		// start epidemics in SYBA
		ask one_of(district where (each.id = 8)){
			I <- 1;
			propagation_level <- 0;
			write "Epidemics starts in "+self.name;
		}
		
		start_district_name <- first(district where (each.I+each.E>0)).name;
		
		write "R0: "+R0;
		create district_transparency;
		
		//convert the files into matrices
		list<matrix> data <- [];
		loop m over: ODMatrices {
			data <- data + [matrix(m)];
		}
		write length(data);
		loop i from: 0 to: data[0].rows -1{
			loop j from: 0 to: data[0].columns - 1{
				create travelers{	
					origin <- first(district where (each.id=i+1));
					destination <- first(district where (each.id=j+1));
					loop k from: 0 to: nb_transportation_modes - 1{
						Ss[k] <- round(int(data[k][j,i])*modes_weights[k]);
						if (origin.name in central_districts) and !(destination.name in central_districts){
							Ss[k] <- int(round(Ss[k]*(1-central_district_travel_weight)));
						}
						if !(origin.name in central_districts) and (destination.name in central_districts){
							Ss[k] <- int(round(Ss[k]*(1+central_district_travel_weight)));
						}
					}
					nb_travelers <- sum(Ss);
				}
				
			}	
		}	
		int total_trips <- travelers sum_of(each.S);	
		write "Total trips per day: "+total_trips;
		max_weight <- max(travelers collect each.nb_travelers);
		max_pop_per_district_2008<-max(district collect each.pop_2008);
		max_pop_per_district_2023<-max(district collect each.pop);
		ask district{
			travelers_from_this_district <- travelers where(each.origin = self);
			travelers_to_this_district <- travelers where(each.destination = self);
			int old_S <- S;
//			write "District "+int(self)+" ("+self.name+") pop: "+S+", travels: "+travelers_from_this_district sum_of(each.S);
			S <- S - travelers_from_this_district sum_of(each.S);
			if S < 0 {
				write "Error: district "+self.name+' has negative initial population ('+S+'). Details:';
				write "Pop before travels: "+old_S;
				loop k from: 0 to: nb_transportation_modes - 1{
					write ""+modes[k]+": "+ travelers_from_this_district sum_of(each.Ss[k]);
				}
				write '';
				ask world {do pause;}
			}
		}
		// computation of the modal_part
		loop k from: 0 to: nb_transportation_modes - 1 {
			modal_part[k] <- travelers sum_of(each.Ss[k]);
		}
	}
	
	
	
	reflex propagate when: moment_of_the_day='day'{
		list<district> districts_with_infection_away <- district where(each.propagation_level = -1 and each.has_infection_away);
		list<district> infection_locations <- district where(each.propagation_level = -1 and each.cycle_total_infections > 0);
		ask infection_locations{
			ask self.travelers_to_this_district where (each.I > 0){
				self.propagation_level <- self.origin.propagation_level;
			}
			self.propagation_level <- 1 + self.travelers_to_this_district where (each.I > 0) min_of(each.propagation_level);
		}
		ask districts_with_infection_away{
			ask self.travelers_from_this_district where (each.E > 0){
				self.propagation_level <- self.destination.propagation_level;
			}
			
			int tmp_level <-  1 + self.travelers_from_this_district where (each.E > 0) min_of(each.propagation_level);
			if (self.propagation_level =-1){
				self.propagation_level <- tmp_level;
			}else{
				self.propagation_level <- min(self.propagation_level,tmp_level);
			}
		}
		
		
		
		
	}
	
	reflex world_update{
		if (mod(cycle,2) = 0){
			moment_of_the_day <- "day";
		}else{
			moment_of_the_day <- "night";
		}
//		write "pop "+total_population+" "+city_R+" (S:"+city_S+'/'+ (district sum_of(each.S));//', E:'+city_E+', I:'+city_I+', Q:'+city_Q+')';
	}
}

species travelers{
	district origin;
	district destination;
//	int weight;
	
	list<int> Ss <- list_with(nb_transportation_modes,0);
	list<int> Es <- list_with(nb_transportation_modes,0);
	list<int> Is <- list_with(nb_transportation_modes,0);
	list<int> Qs <- list_with(nb_transportation_modes,0);
	list<int> Rs <- list_with(nb_transportation_modes,0);
	
	int S -> sum(Ss);	
	int E -> sum(Es);
	int I -> sum(Is);
	int Q -> sum(Qs);
	int R -> sum(Rs);
	
	int propagation_level <- -1;
	
	int nb_travelers;// -> S+E+I+Q+R;
	
	aspect default{
		if (E+I > link_threshold){
			rgb lineColor <- blend(#gamared,#white,10*(E+I)/(S+I+E+R));
			draw curve(origin.location,destination.location,0.5,20, 0.8,90) end_arrow: 100  width:(nb_travelers/max_weight)*5 color:lineColor;		
		}
//		if (nb_travelers > weight_threshold*trip_scale){
//			rgb lineColor <- blend(#gamared,#white,10*(E+I)/(S+E+I+R));
//			draw curve(origin.location,destination.location,0.5,20, 0.8,90) end_arrow: 100  width:(nb_travelers/max_weight)*10 color:lineColor;		
//		}
	}
	
	aspect propagation{
		if (propagation_level >= 0){
			rgb lineColor <- rgb(#red,0.7^propagation_level);
			draw curve(origin.location,destination.location,0.5,20, 0.8,90) end_arrow: 100  width: 5*0.7^propagation_level color: lineColor;		
		}
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
	int S <-0;
	int E <-0;
	int I <-0;
	int Q <- 0;
	int R <-0;
	int propagation_level <- -1;
	list<travelers> travelers_from_this_district;
	list<travelers> travelers_to_this_district;
	int local_infected_pop <- E+I + travelers_from_this_district sum_of (each.E+each.I);
	
	bool has_infection_away -> travelers_from_this_district sum_of (each.E) > 0;
	
	
	int local_pop -> S+E+I+Q+R;
	
	int cycle_total_infections <- 0;
	
	reflex infection when: (pop != 0){
		list<travelers> travelers_at_district;
		if (moment_of_the_day = 'day'){
			travelers_at_district <- travelers_to_this_district;//day 
		}else{
			travelers_at_district <- travelers_from_this_district;//night
		}
		

		int total_I <- I + sum(travelers_at_district collect(each.I));
		int total_Q <- Q + sum(travelers_at_district collect(each.Q));

		int total_pop <- local_pop + sum(travelers_at_district collect(each.nb_travelers));

		// infection probability is infected by one infected indiv.: p = p_inf * p_contact, with p_contact = nb_contact/total_pop 
		// probability of infection with I infected individuals 1-(1-p)^I
		
		float infection_probability_per_inf_indiv <- infection_probability * avg_contacts[moment_of_the_day]/total_pop;
		float infection_rate <- 1 - (1-infection_probability_per_inf_indiv)^total_I;

		int nb_infections <- binomial(S,infection_rate);
		int to_infected <- binomial(E,incubation_to_infection_rate);
		int to_quarantine <- binomial(I,quarantine_rate);
		int infected_to_recovered <- binomial(I,recovery_rate);
		if (infected_to_recovered + to_quarantine > I){// too many individuals leaving compartment I
			to_quarantine <- I - infected_to_recovered;
		}
		int quarantined_to_recovered <- binomial(Q,recovery_rate);

		map<travelers, int> infection_candidates<- travelers_at_district as_map(each::each.I);
		int travelers_weight <- sum(infection_candidates.values);
		int district_weight <- I;

		S <- S - nb_infections;	
		E <- E + nb_infections - to_infected;
		I <- I + to_infected - to_quarantine - infected_to_recovered;
		Q <- Q + to_quarantine - quarantined_to_recovered;
		R <- R + infected_to_recovered + quarantined_to_recovered;
			
		cycle_total_infections <- nb_infections;

		ask travelers_at_district{
			
			loop i from: 0 to: nb_transportation_modes-1{
				nb_infections <- binomial(self.Ss[i],infection_rate);
				to_infected <- binomial(self.Es[i],incubation_to_infection_rate);
				to_quarantine <- binomial(self.Is[i],quarantine_rate);
				infected_to_recovered <- binomial(self.Is[i],recovery_rate);
				quarantined_to_recovered <- binomial(self.Qs[i],recovery_rate);	
				if (infected_to_recovered + to_quarantine > Is[i]){// too many individuals leaving compartment I
					to_quarantine <- Is[i] - infected_to_recovered;
				}
				self.Ss[i] <- self.Ss[i] - nb_infections;
				self.Es[i] <- self.Es[i] + nb_infections - to_infected;
				self.Is[i] <- self.Is[i] + to_infected - to_quarantine - infected_to_recovered;
				self.Qs[i] <- self.Qs[i] + to_quarantine - quarantined_to_recovered;
				self.Rs[i] <- self.Rs[i] + infected_to_recovered + quarantined_to_recovered;
				
				myself.cycle_total_infections <- myself.cycle_total_infections + nb_infections;
			}
			
		}
	}
	
	reflex create_focuses{
		int i <- 0;
		loop while: i < cycle_total_infections {
			create focus{
				location <- any_location_in(myself.shape);
				number <- round(0.6+gamma_rnd(1.0,4.0));
//				write number;
				i <- i + number;
			} 
		}
	}
	
	aspect base{
		if zone in central_districts{
			draw shape color:#grey border:#black;
		}else{
			draw shape color:#white border:#black;
		}
		
//		loop i from:1 to: floor(cycle_total_infections) step: 1 {
//			draw circle(40) color: #red at: any_location_in(self.shape);
//		}
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
	}	
}

species road{
	aspect default {
		draw shape color:rgb(50,100,50) border:#black width:1;
	}
}

species focus{
	int duration <- 0;
	int number;
	
	reflex fade{
		duration <- duration + 1;
		if duration > 2 * focus_half_life{
			do die;
		}
	}
	
	
	aspect default{
		float alpha <- duration <= focus_half_life? duration/focus_half_life: 1 - (duration -focus_half_life)/focus_half_life;
		draw circle(10*sqrt(number)) color: rgb(#red,alpha);
	}
	
	
}



experiment IMaroc type: gui {
	float w -> simulation.shape.width; 
	float h -> simulation.shape.height;
	float minimum_cycle_duration <- 0.1;
	output autosave: false {
		layout vertical([horizontal([0::100,1::100])::100,horizontal([2::100,horizontal([3::100,4::100])::100])::100])
			;// tabs: false consoles: false parameters: false navigator: false toolbars: false tray: false;//controls: false
		display Population type: 3d axes:false toolbar:false background:rgb(0,50,0){
			camera #default locked: true location: {w *0.55, h * 1.3, w*2/3 } target: {w *0.55, h * 0.6, 0} dynamic: true;
			graphics "info"{ 		
				draw "I-Maroc" at:{0,-1600} color: #white font: font("Helvetica", 20 , #bold);
				draw "Number of declared cases: "  + city_I at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
			}
			species district aspect:pop position:{0,0,-0.01};
			species district_transparency;
		}
		
		display Propagation type: 3d axes:false toolbar:false background:rgb(0,50,0){
			camera #default locked: true location: {w *0.55, h * 1.3, w*2/3 } target: {w *0.55, h * 0.6, 0} dynamic: true;			
			graphics "info"{ 
				draw "Propagation map" at:{0,-2000} color: #white font: font("Helvetica", 20 , #bold);
				draw "Start district: "  + start_district_name at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
			}
			species district aspect:base position:{0,0,-0.01} transparency:0.25;
			species travelers aspect: propagation;
			species focus;
			species road transparency: 0.8;
		}
		display "Epidemics" toolbar:false background:rgb(0,50,0){
		    chart "Epidemics" type: series  background:rgb(0,50,0) color:#white tick_line_color: #white{
				data "Prevalence" value: city_I color: #red marker: false;
				data "Total recoveries" value: city_R color: #orange marker: false;
				data "Quarantined" value: city_Q color: rgb(100,100,255) marker: false;
		    }
		}
		display "Transportation modes" toolbar: false background: rgb(0,50,0){
			chart "Modality part" type: pie  background:rgb(0,50,0) color:#white{
				loop i from: 0 to: nb_transportation_modes-1{
					data modes[i] value: modal_part[i] color: color_per_mode[i];
				}
		    }
		}
		display "Infection per modes" toolbar: false background: rgb(0,50,0){
		    chart "Infection propagation per mode" type: pie  background:rgb(0,50,0) color:#white{
				loop i from: 0 to: nb_transportation_modes-1{
					data modes[i] value: travelers sum_of (each.Is[i]) color: color_per_mode[i];
				}
		    }
		}
	}
}


experiment comparison type: gui {
	float w -> simulation.shape.width; 
	float h -> simulation.shape.height;
	float minimum_cycle_duration <- 0.1;
	
	init {
		create simulation with: [quarantine_rate:: 0.04];	
	}
	
	permanent {	
		display Epidemics type: 2d toolbar:false background:rgb(50,50,50) {
			chart "Epidemics" type: series  background:rgb(0,50,0) x_range: [0,220] 
					y_range: [0,1000000] color:#white tick_line_color: #white legend_font: font("Arial", 12)
					label_font: font("Arial", 12){
				data "Prevalence" value: simulations[0].city_I color: rgb(#red,0.9) line_visible: false marker_shape: marker_circle marker_size: 0.5;
				data "Total recoveries" value: simulations[0].city_R color: rgb(#orange,0.9) line_visible: false marker_shape: marker_circle marker_size: 0.5;
				data "Prevalence (quarantine)" value: simulations[1].city_I color: #red marker: false thickness: 2;
				data "Total recoveries (quarantine)" value: simulations[1].city_R color: #orange marker: false thickness: 2;
				data "Quarantined (quarantine)" value: simulations[1].city_Q color: rgb(100,100,255) marker: false thickness: 2;
		    }
		}
	}
	
	output autosave: true{
//		layout vertical([horizontal([0::100,1::100])::100,2::100]) tabs:false editors: false consoles: false parameters: false navigator: false toolbars: false tray: false controls: false;
		layout horizontal([0::100,vertical([1::100,2::100])::100]) tabs:false editors: false consoles: false parameters: false navigator: false toolbars: false tray: false controls: false;
		display Propagation type: 3d axes:false toolbar:false background:rgb(0,50,0) camera: #default{
			camera #default locked: true location: {w *0.55, h * 1.3, w*2/3 } target: {w *0.55, h * 0.6, 0} dynamic: true;
			graphics "info"{ 
				draw "Quarantine rate: " + quarantine_rate at:{0,-2000} color: #white font: font("Helvetica", 20 , #bold);
				draw "Total Cases: " +(city_E+city_I+city_R)  at:{0,-1000}  color: #white font: font("Helvetica", 14 , #bold);
			}
			species district aspect:base position:{0,0,-0.01} transparency:0.25;
			species travelers aspect: default;
			species focus;
			species road transparency: 0.8;
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
