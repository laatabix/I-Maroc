library(ggplot2)

setwd("L:/PROJECTS/iMaroc/I-Maroc-repo/IMaroc_GAMA/results/")

data00 = read.csv("notraffic_notransfer/completedtrips.csv",header=T)
data00$traffic = "Sans congestion"
data00$transfer= "0:Sans transfert"

data01 = read.csv("notraffic_transfer_Bus/completedtrips.csv",header=T)
data01$traffic = "Sans congestion"
data01$transfer= "1:Bus"

data02 = read.csv("notraffic_transfer_BusBRT/completedtrips.csv",header=T)
data02$traffic = "Sans congestion"
data02$transfer= "2:Bus-BRT"

data03 = read.csv("notraffic_transfer_BusBRTTaxi/completedtrips.csv",header=T)
data03$traffic = "Sans congestion"
data03$transfer= "3:Bus-BRT-Taxis"

data10 = read.csv("traffic_notransfer/completedtrips.csv",header=T)
data10$traffic = "Avec congestion"
data10$transfer= "0:Sans transfert"

data11 = read.csv("traffic_transfer_Bus/completedtrips.csv",header=T)
data11$traffic = "Avec congestion"
data11$transfer= "1:Bus"

data12 = read.csv("traffic_transfer_BusBRT/completedtrips.csv",header=T)
data12$traffic = "Avec congestion"
data12$transfer= "2:Bus-BRT"

data13 = read.csv("traffic_transfer_BusBRTTaxi/completedtrips.csv",header=T)
data13$traffic = "Avec congestion"
data13$transfer= "3:Bus-BRT-Taxis"


data = rbind(data00,data01,data02,data03,
             data10,data11,data12,data13)

data$wtime = data$board_time - data$wait_time
data$ttime = data$arrival_time - data$board_time

################################################
dd = data[data$trip_type !=2,]

dd[dd$trip_type==1,]$trip_type = "1:Simple"
dd[dd$trip_type==3,]$trip_type = "2:Double"

ggplot(dd, aes(fill=trip_type, x=transfer)) +
  geom_bar(position='dodge') +
  theme_bw() + facet_wrap(~traffic,ncol=1) 

dd = data
dd[dd$line_type==21,]$line_type = "1:Bus"
dd[dd$line_type==22,]$line_type = "2:BRT"
dd[dd$line_type==23,]$line_type = "3:Taxis"

ggplot(dd, aes(fill=line_type, x=transfer)) +
  geom_bar(position='dodge') +
  theme_bw() + facet_wrap(~traffic,ncol=1) 
#############

dd = data
dd[dd$trip_type==1,]$trip_type = "0:Simple"
dd[dd$trip_type==2,]$trip_type = "1:Double-1"
dd[dd$trip_type==3,]$trip_type = "2:Double-2"
dd[dd$line_type==21,]$line_type = "1:Bus"
dd[dd$line_type==22,]$line_type = "2:BRT"
dd[dd$line_type==23,]$line_type = "3:Taxis"

ggplot(dd, aes(fill=trip_type, y=ride_distance/1000,x=line_type)) +
  geom_boxplot() +
  theme_bw() + facet_wrap(~transfer,nrow=1) 



boxplot(dd$ttime/60~dd$trip_type, xlab = "Type de voyage", ylab="Temps de voyage",
        col=c("palegreen","white","gray"))


dx = data10
dx[dx$line_type==21,]$line_type = "1:Bus"
dx[dx$line_type==22,]$line_type = "2:BRT"
dx[dx$line_type==23,]$line_type = "3:Taxis"
dx[dx$trip_type==1,]$trip_type = "0:Simple"
dx[dx$trip_type==2,]$trip_type = "1:Double-1"
dx[dx$trip_type==3,]$trip_type = "2:Double-2"
dx$wtime = dx$board_time - dx$wait_time
dx$ttime = dx$arrival_time - dx$board_time

#plot(dx$ride_distance/1000,dx$ttime/60, col=factor(dx$direction),
#     xlim=c(0,30),ylim=c(0,60),
#     xlab = "Distance", ylab="Temps de voyage")


boxplot(dx$wtime/60~dx$trip_type, xlab = "Type de voyage",
        ylab="Temps d'attente", ylim=c(0,30),
        col=c("palegreen","white","gray"))






pie(table(data[data$trip_type<3,]$trip_type), col=c("white","gray"))


table(data$trip_type)





