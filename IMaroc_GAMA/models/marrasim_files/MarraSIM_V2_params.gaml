/**
* Name: Params
* Description: this file stores general and main parameters.
* Authors: Laatabi, Benchra
* For the i-Maroc project. 
*/

model Params

global {
	bool BUS_ON <- true;
	bool BRT_ON <- true;
	bool TAXI_ON <- true;
	bool traffic_on <- false;
	
	int DIRECTION_OUTGOING <- 1;
	int DIRECTION_RETURN <- 2;
	
	// speed of busses in the urban area
	float BUS_URBAN_SPEED <- 25#km/#hour;
	// speed of BRTs and Taxis
	float BRT_SPEED <- 40#km/#hour;
	float TAXI_SPEED <- 30#km/#hour;
	
	// speed of busses in the suburban area
	float BUS_SUBURBAN_SPEED <- 60#km/#hour;
	
	// the minimum wait time at bus stops
	float MIN_WAIT_TIME_STOP <- 5#second;
	
	// simulation starts at 06:00 morning
	float SIM_START_HOUR <- 6#hour;
	
	font AFONT0 <- font("Calibri", 16, #bold);
	
	/****************************************/	
	/**************** STATS ****************/
	int number_of_completed_bus_trips <- 0;
	int number_of_completed_brt_trips <- 0;
	int number_of_completed_taxi_trips <- 0;
	
	list<int> wtimes_completed_bus_trips <- [];
	list<int> wtimes_completed_brt_trips <- [];
	list<int> wtimes_completed_taxi_trips <- [];
	
	list<int> triptimes_completed_bus_trips <- [];
	list<int> triptimes_completed_brt_trips <- [];
	list<int> triptimes_completed_taxi_trips <- [];
	/****************************************/	
	/***************************************/
}

