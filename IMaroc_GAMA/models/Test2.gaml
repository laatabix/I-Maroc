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
		
		point p0 <- {20,15};
		point p1 <- {20,75};
		point p2 <- {80,75};
		point p3 <- {80,15};
		point p4 <- {40,15};
		point p5 <- {40,60};
		
		list<point> all_points <- [];
			
		create _line_ {
			_points_ <<+ (polyline(p0,p1,p2,p3,p4,p5)).points;
			all_points <<+ _points_;
			_color_ <- #red;
		}
		
		create _line_ {
			_points_ <<+ (polyline(p0,p1,p2,p3,p4,p5)).points;
			int lisize <- length(_points_)-1;
			loop i from: 0 to: lisize {
				point pp <- _points_[i];
				int transx <- 0;
				int transy <- 0;
				if !empty(all_points) and all_points min_of (each distance_to pp) = 0 {
					write "------ inif " + i;
					point prevp;
					point nextp;
					
					if i = 0 {
						prevp <- pp;//{#min_float,#max_float};
						nextp <- _points_[i+1];
					} else if i = lisize {
						nextp <- pp;//{#min_float,#max_float};
						prevp <- _points_[i-1];
					} else {
						prevp <- _points_[i-1];
						nextp <- _points_[i+1];
					}
					/***/
					if prevp.x = pp.x and pp.x = nextp.x {
						transx <- 2;
					}
					 else if prevp.x > pp.x and i!= lisize {//and prevp.y < pp.y {
						transx <- 2;
					} else if prevp.x < pp.x{//} and prevp.y < pp.y {
						transx <- -2;
					}
					/***/
					if pp.y = nextp.y and nextp.y > prevp.y{
						transy <- -2;
					}
					else if /*i!= lisize and*/  pp.y = nextp.y and nextp.y < prevp.y{
						transy <- 2;
					}
					else if nextp.y < pp.y {
						transy <- -2;
					}

												
					_points_[i] <- point(pp translated_by {transx,transy});//translated_by {1,-2};
				}
			}
			

			_color_ <- #blue;
		}
	}
		
}


species _line_ skills: [moving]{
	
	list<point> _points_ <- [];
	rgb _color_;
	
	aspect default {
		loop i from: 0 to: length(_points_)-1 {
			draw circle (1) color: #black at: _points_[i];
			if i > 0 {
				draw line(_points_[i-1],_points_[i]) color: _color_;
			}
			
		}
	}
}


experiment Test type: gui {
	/** Insert here the definition of the input and output of the model */
	output {
		
		display mapp {
			species _line_;
		}
	}
}
