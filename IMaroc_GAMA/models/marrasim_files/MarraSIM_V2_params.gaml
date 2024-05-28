/**
* Name: Params
* Description: this file stores general and main parameters.
* Authors: Laatabi
* For the i-Maroc project. 
*/

model Params

global {
	
	/********* Simulation *********/
	float sim_id; // a unique simulation id for data storage
	// whether to save simulation data (to /outputs) or not
	bool save_data_on <- true;
	
	bool BUS_ON <- true;
	bool BRT_ON <- true;
	bool TAXI_ON <- true;
	
	bool traffic_on <- false;
	bool transfer_on <- true;
	bool time_tables_on <- false;
	
	int DIRECTION_OUTGOING <- 1;
	int DIRECTION_RETURN <- 2;
	
	// speed of busses in the suburban/urban area
	float BUS_SUBURBAN_SPEED <- 60#km/#hour;
	float BUS_URBAN_SPEED <- 40#km/#hour;
	
	// speed of BRTs and Taxis
	float BRT_SPEED <- 50#km/#hour;
	float TAXI_FREE_SPEED <- 50#km/#hour;
	float TAXI_TRAFFIC_SPEED <- 30#km/#hour;
	
	float DEFAULT_INTERVAL_TIME_BUS_URBAN <- 15 #minute;
	float DEFAULT_INTERVAL_TIME_BUS_SUBURBAN <- 30 #minute;
	float DEFAULT_INTERVAL_TIME_BRT <- 15 #minute;
	float DEFAULT_INTERVAL_TIME_Taxi <- 10 #minute;
	
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

