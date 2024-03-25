/**
* Name: Test
* Based on the internal skeleton template. 
* Author: Laatabi
* Tags: 
*/

model Test

global {
	
	geometry shape <- square(100);
	
	init {
		
		create _point_ {
			location <- {20,15};
		}
		create _point_ {
			location <- {30,75};
		}
		create _point_ {
			location <- {80,40};
		}
		
		list<geometry> all_geoms <- [];
		
		create _line_ {
			geometry geom <- (polyline(_point_[0],_point_[1],_point_[2]));
			loop i from: 1 to: length(geom.points)-1 {
				geometry gg <- line(geom.points[i-1],geom.points[i]);
				lines <+ gg;
				all_geoms <+ gg;
			}
			
			write length(lines);
			_color_ <- #red;
		}
		
		
		create _line_ {
			geometry geom <- (polyline(_point_[0],_point_[1],_point_[2]));
			loop i from: 1 to: length(geom.points)-1 {
				geometry gg <- line(geom.points[i-1],geom.points[i]);
				if !empty(all_geoms) and all_geoms min_of (each distance_to gg) <= 1 {
					geometry closer <- all_geoms closest_to self;
					gg <- gg translated_by {2,1};//translated_by {1,-2};
				}
				lines <+ gg;
				all_geoms <+ gg;
			}
			_color_ <- #blue;
		}
	}
		
}

species _point_ {
		
	aspect default {
		draw circle (1) color: #black;
	} 
}

species _line_ skills: [moving]{
	
	list<geometry> lines <- [];
	rgb _color_;
	
	aspect default {
		loop ln over: lines {
			draw ln color: _color_ at: ln.location;
		}
	}
}


experiment Test type: gui {
	/** Insert here the definition of the input and output of the model */
	output {
		
		display mapp {
			species _point_;
			species _line_;
		}
	}
}
