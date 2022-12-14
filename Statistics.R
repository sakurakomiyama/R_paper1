rm(list=ls())
library(dplyr)
library(data.table)
library(ggplot2)
my_theme <- function() theme_bw(base_size=15) + theme(panel.grid.minor = element_blank(), panel.grid.major = element_blank())

#================================#
####         Load data        ####
#================================#
lapply(c("Data/sandeel.Rdata", "Data/School_EROS.Rdata", "Data/spdf.Rdata", "gps.Rdata"),load,.GlobalEnv)
School_EROS.dt <- School.dt
rm(School.dt)
#== add coverage_name ==#
School_EROS.dt <- School_EROS.dt[Frequency %in% 200 & category%in%"SAND"]
label <- unique(data.table(vessel = gps.dt$vessel, coverage_name = gps.dt$coverage_name, 
                           StartTime = gps.dt$StartTime, StopTime = gps.dt$StopTime,
                           distance_sum = gps.dt$distance_sum, area = gps.dt$area))
setDT(School_EROS.dt)[setDT(label), on =. (YMD_time >= StartTime, 
                                       YMD_time <= StopTime,
                                       area == area, vessel == vessel), 
                  coverage_name := coverage_name]


#====     LDA results & env.data  =========# (if needed)
lapply(c("Data/score.Rdata", "Data/coef.Rdata", "Data/confusion.matrix.Rdata"),load,.GlobalEnv)
load("C:/Users/a37907/Desktop/KnowSandeel15781/Data/slda.lst.Rdata")
load("C:/Users/a37907/Desktop/KnowSandeel15781/Data/env.Rdata")
#==========================================#


#====  combine SD and EROS  ====#
data <- rbind(sandeel.dt, School_EROS.dt[Frequency%in%200 & category%in%"SAND" & !area %in% "outside" ]) #rbind(sandeel.dt, School_EROS.dt[Frequency%in%200 & category%in%"SAND" & !area %in% "outside" ]) #sandeel.dt #& school_area >= median(School_EROS.dt$school_area)
data$month <- strftime(data$YMD_time, "%m", tz="UTC")
data <- mutate (data, month_name = case_when (month=="04"~"April", month=="05"~"May", month=="06"~"June", month=="07"~"July~", TRUE ~"July~"))
data <- mutate (data, area_2 = case_when (area=="AlbjoernLing" ~ "AlbjoernLing", area=="VestbankenSouthEast" ~ "Vestbanken",area=="VestbankenSouthWest" ~ "Vestbanken", area=="Vestbanken_North" ~ "Vestbanken",area=="Vikingbanken" ~ "Vikingbanken", area=="Engelsk_Klondyke" ~ "Engelish Klondyke",area=="Inner_Shoal_East_2016" ~ "Inner Shoal", area=="Inner_Shoal_North" ~ "Inner Shoal",area=="Inner_Shoal_West_2018" ~ "Inner Shoal", area=="Inner_Shoal_test" ~ "Inner Shoal",area=="Nordgyden" ~ "Nordgyden", area=="Ostbanken" ~ "Ostbanken", area=="Outer_Shoal" ~ "Outer Shoal",TRUE ~ "NA"))
#data[, .(cnt= sum(.N)), by= c("vessel", "area")]
#gps.dt[!coverage_name%in%c("F","x")][, .(cnt= sum(.N)), by= c("vessel", "coverage_name", "area")]

#== add coverage_name  ==# (need gps.dt)
coverage.dt <- unique(data.table(vessel=gps.dt$vessel, area=gps.dt$area, Time_start=gps.dt$StartTime, Time_end=gps.dt$StopTime, coverage_name=gps.dt$coverage_name))
coverage.dt <- coverage.dt[!coverage_name %in% c("F","x", "Transect")]
ggplot()+geom_point(data=coverage.dt, aes(x=Time_start, y=coverage_name, col=vessel), size=2)+geom_point(data=coverage.dt, aes(x=Time_end, y=coverage_name, col=vessel), size=2) + facet_wrap(.~vessel, scales="free", ncol=1)
#= find acoustic schools within trawl operation (position min~max) =#
setDT(data)[setDT(coverage.dt), on =. (vessel==vessel, area==area, YMD_time>=Time_start, YMD_time<=Time_end), coverage_name := coverage_name]
setDT(data)[, coverage_name := ifelse(is.na(coverage_name), "x", coverage_name )]
#== add coverage_name_2 ==#
setDT(data)[,time_mean:=mean(YMD_time), by=(coverage_name)]
tmp <- unique(data.table(coverage_name=data$coverage_name, time=data$time_mean, area=data$area))
tmp <- tmp[order(area, time),][!coverage_name%in%"x"]
setDT(tmp)[, No:= 1:.N, by=area][, coverage_name_2:=paste(area,No,sep="-")][,area:=NULL][, time:=NULL]
data <- merge(x = data, y = tmp, by = "coverage_name", all.x = TRUE)


#== plot ==#
# NASC vs time of day
ggplot()+theme_bw()+geom_boxplot(data=data, aes(x=strftime(data$YMD_time, "%H", tz="UTC"), y=log(sA)), shape=1)+labs(x="Time of day", y="log(school NASC)")

# depth vs time of day
library(ggpubr)
mean <- ggplot()+theme_bw()+geom_boxplot(data=data, aes(x=strftime(data$YMD_time, "%H", tz="UTC"), y=nor_Depth*-100), shape=1)+labs(x="Time of day", y="weighted mean depth")
min <- ggplot()+theme_bw()+geom_boxplot(data=data, aes(x=strftime(data$YMD_time, "%H", tz="UTC"), y=nor_DepthStart*-100), shape=1)+labs(x="Time of day", y="minimum depth")
max <- ggplot()+theme_bw()+geom_boxplot(data=data, aes(x=strftime(data$YMD_time, "%H", tz="UTC"), y=nor_DepthStop*-100), shape=1)+labs(x="Time of day", y="maximum depth")
height <- ggplot()+theme_bw()+geom_boxplot(data=data, aes(x=strftime(data$YMD_time, "%H", tz="UTC"), y=school_height), shape=1)+labs(x="Time of day", y="school height")
ggarrange(mean, min, max, height, labels = c("A", "B", "C", "D"), ncol = 2, nrow = 2) #, norm + rremove("x.text")




#=========================#
####     vertical      ####
#=========================#
#== go to the logistic model ==#

sandeel.dt |>
  mutate(time = strftime(YMD_time, "%H:%M", tz="UTC")) |>
  mutate(time = as.POSIXct(time, format = "%H:%M")) |>
  ggplot() + my_theme() +
  geom_point(aes(y = nor_Depth*-1, 
                 x = time, # altitude_degree (if use altitude, comment out "scale_x_datetime()")
                 colour = vessel),
             shape = 1, alpha = 1) +
  scale_x_datetime(date_labels="%H") +
  #facet_wrap(~strftime(YMD_time, "%m", tz="UTC")) + 
  facet_wrap(~strftime(YMD_time, "%W", tz="UTC")) + 
  labs(y = "normalised depth", x = "time of day")


l <- c("April", "May", "June", "July", "August")
names(l) <- c("04", "05", "06", "07", "08")

## "Vestbanken","Engelish Klondyke","AlbjoernLing", "Vikingbanken" 
## "Inner Shoal", "Nordgyden", "Ostbanken", "Outer_Shoal"
a = c("Engelish Klondyke")

ggplot() +
  my_theme() + theme(axis.title.x = element_blank()) + 
  geom_boxplot(data = data[area_2%in%a], aes(x = month, y = meanDepth, fill = vessel)) + 
  scale_y_reverse() + 
  scale_x_discrete(labels = l) +
  labs(y="Depth of school (m)", title = a)
#

ggplot() +
  theme_bw(base_size=15) + theme(panel.grid.minor = element_blank(), panel.grid.major = element_blank(), axis.title.x = element_blank(), axis.text.x = element_text(angle=90)) + 
  geom_boxplot(data = data[!is.na(coverage_name_2)], aes(x=coverage_name_2, y=nor_Depth, fill=vessel)) + scale_y_reverse() + 
  labs(y="Depth of school (m)")
#




#============================#
#### time series analysis ####
#============================#

#== gps data ==#
label <- unique(data.table(vessel = gps.dt$vessel, coverage_name = gps.dt$coverage_name, 
                   StartTime = gps.dt$StartTime, StopTime = gps.dt$StopTime,
                   distance_sum = gps.dt$distance_sum, area = gps.dt$area))
spdf_tmp <-  data.table(merge(x = spdf, y = label, by = "area", all.x = TRUE))

#= plot gps and school by coverage_name =#
## "Engelsk_Klondyke", "Vikingbanken","AlbjoernLing", "Ostbanken", "Nordgyden", "Outer_Shoal"
## "Inner_Shoal_East_2016", "Inner_Shoal_North", "Inner_Shoal_test", "Inner_Shoal_West_2018"
## "Vestbanken_North", "VestbankenSouthEast", "VestbankenSouthWest"
a <- c("Vestbanken_North", "VestbankenSouthEast", "VestbankenSouthWest")
v <- c("SD1031")
text <- label[label$area %in% a & label$vessel %in% v]
spdf_coverage_name <- spdf_tmp[spdf_tmp$coverage_name %in% text$coverage_name ]
ggplot() + my_theme() + 
  geom_path(data = gps.dt[vessel %in% v & area %in% a], 
                     aes(x = Longitude, y = Latitude), lwd =.1) + 
  geom_polygon(data= spdf_coverage_name, aes(long,lat, group=area), col="black", alpha=.2) + 
  geom_text(data = text, aes(x = -Inf, y = Inf, label = StartTime), hjust   = 0, vjust   = 1) + 
  geom_text(data = text, aes(x = -Inf, y = -Inf, label = StopTime), hjust   = 0, vjust   = 0) +
  geom_point(data = sandeel.dt[area %in% a & vessel %in% v], 
             aes(x = Longitude, y = Latitude), shape = 1, size = 1, col = "red") +
  facet_wrap(~coverage_name, scales="free")

#= gps and SD school by month =#
m <- as.character("06")
ggplot() + 
  geom_path(data = gps.dt[month %in% m & vessel %in% c("SD1031", "SD1032")], 
            aes(x = Longitude, y = Latitude, colour = vessel), lwd =.1) +
  geom_polygon(data= spdf, aes(long,lat, group=area), col="black", alpha=.2) + 
  geom_point(data = sandeel.dt[strftime(YMD_time, "%m", tz="UTC") %in% m], 
             aes(x = Longitude, y = Latitude), shape = 1, size = 1)
#==============================#


#==  calculate sL   ==#
data <- rbind(sandeel.dt, School_EROS.dt) 
data[, .(cnt= sum(.N)), by= c("vessel", "coverage_name", "area")]
setDT(data)[, sA_sum:= sum(sA), by=c("coverage_name", "vessel")]
data[label, on = 'coverage_name', distance_sum := distance_sum]
data$sL <- data$sA_sum/data$distance_sum
data[ ,YMD_time_mean := mean(YMD_time), by=c("coverage_name", "vessel")]
library(lubridate)
data[ ,Julian_day := yday(YMD_time_mean)]

# plot
library(ggrepel)
ggplot() + my_theme() + theme(legend.position = "none", axis.title.x = element_blank())+
  geom_point(data = data[!vessel %in% "EROS" & !coverage_name %like% ".x"], 
             aes(x = YMD_time_mean, y = log(sL), fill=vessel), shape = 21) +
  #geom_point(data = data[!vessel %in% "EROS" & coverage_name %like% ".x"], 
  #           aes(x = YMD_time_mean, y = log(sL)), fill = "white", shape = 21) +
  #geom_label_repel(data = data[!vessel %in% "EROS" & !duplicated(data[,c('coverage_name')]),],
  #                 aes(x = YMD_time_mean, y = log(sL), label = area),
  #                 box.padding   = .5, label.padding = .15, point.padding = .1, 
  #                 force = 10, max.overlaps = length(unique(data$coverage_name)), 
  #                 min.segment.length = .1 ,size = 2) + 
  xlim(min(data$YMD_time_mean),max(data$YMD_time_mean)) + 
  ylim(min(log(data$sL)), max(log(data$sL))) + 
  labs(y="log(total school NASC / travel distance)")
#======================#



#== GAM ==#
library(mgcv)
gam_sL <- gam(log(sL) ~  s(Julian_day), #s(unclass(YMD_time_mean)), 
              data = data[!vessel %in% "EROS" & 
                          !coverage_name %like% ".x" & 
                          !duplicated(data[,c('coverage_name')]),], 
              family = gaussian )

gam_sL_EROS <- gam(log(sL) ~ s(Julian_day), #s(unclass(YMD_time_mean)),  
              data = data[!coverage_name %like% ".x" & 
                            !duplicated(data[,c('coverage_name')]),], 
              family = gaussian )

lm_sL <- lm(log(sL) ~ unclass(YMD_time_mean), 
              data = data[!vessel %in% "EROS" & 
                            !coverage_name %like% ".x" & 
                            !duplicated(data[,c('coverage_name')]),])

ggplot(cbind(data[
    #!vessel %in% "EROS" & 
    !coverage_name %like% ".x" & 
    !duplicated(data[,c('coverage_name')]),],
             fit = fitted(gam_sL_EROS)),
             aes(x = Julian_day, y = log(sL))) +
  geom_point(aes(fill = vessel), shape = 21) + 
  my_theme() + theme(legend.position = c(.9,.2)) + 
  geom_line(aes(y = fit), colour = "red") +
  geom_smooth(method='lm', formula= y~x, se = FALSE, col = "black", lwd = .5) +
  xlim(min(data$Julian_day), max(data$Julian_day)) + 
  ylim(min(log(data$sL)), max(log(data$sL))) + 
  labs(x = "", y = "log(total school NASC / travel distance)")

#=========#





























































































































#========================================================================================================================#
#### test code    ####  
#========================================================================================================================#

#===========================#
####      horizontal     ####
#===========================#

#==================================================#
####   center of gravity (local distribution)   ####
#==================================================#

#== calculate center of gravity ==#
setDT(data)[, center_of_gravity_Lat:= crossprod(Latitude,sA)/sum(sA), by=(coverage_name)][, center_of_gravity_Long:= crossprod(Longitude,sA)/sum(sA), by=(coverage_name)]

#

## "Engelsk_Klondyke", "Vikingbanken","AlbjoernLing", "Ostbanken", "Nordgyden", "Outer_Shoal"
## "Inner_Shoal_East_2016", "Inner_Shoal_North", "Inner_Shoal_test", "Inner_Shoal_West_2018"
## "Vestbanken_North", "VestbankenSouthEast", "VestbankenSouthWest"
a <- c("AlbjoernLing", "Ostbanken")
ggplot() + theme_bw() + theme(panel.grid = element_blank(), axis.title = element_blank()) + 
  geom_point(data=gps.dt[area%in%a & !coverage_name %in% c("F","x", "Transect")], aes(x=Longitude, y=Latitude),col="grey", size=.05, alpha =0.2) +
  geom_point(data=data[area%in%a & !coverage_name %in% c("F","x", "Transect")], aes(Longitude, Latitude, size = sA), alpha = 0.5)+ 
  scale_size_continuous(limits = c(0, 439373.7), range = c(0.1,20), breaks = c(500,5000, 10000, 50000)) + 
  geom_point(data=data[area %in% a & !coverage_name %in% c("F","x", "Transect")], aes(center_of_gravity_Long,center_of_gravity_Lat), col="red", size=5) + 
  facet_wrap(~coverage_name, scales="free")
#  
#

setDT(data)[,sA_sum:=sum(sA), by=c("coverage_name", "vessel")]
center_of_gravity <- with(data, aggregate(data[,c("Latitude", "Longitude", "YMD_time", "DepthStart", "DepthStop","sV_mean","rf","school_length", "meanDepth", "weighted_meanDepth","nor_Depth","nor_DepthStart", "nor_DepthStop", "DepthfromBottom")], 
                                          list(vessel, sA_sum, coverage_name, center_of_gravity_Lat,  center_of_gravity_Long), mean))
setnames(center_of_gravity, c("Group.1", "Group.2", "Group.3", "Group.4", "Group.5"), 
         c("vessel", "sA_sum", "coverage_name", "center_of_gravity_Lat",  "center_of_gravity_Long"))
setDT(center_of_gravity)[, area:=sub(".*- *(.*?) *-.*", "\\1", center_of_gravity$coverage_name)]
center_of_gravity <- center_of_gravity[order(area, YMD_time),]
setDT(center_of_gravity)[, No:= 1:.N, by=area][, coverage_name_2:=paste(area,No,sep="-")]#[,No:=NULL]
setDT(center_of_gravity)[, relative_Lat:=center_of_gravity_Lat-center_of_gravity_Lat[No==1], by = (area)][, relative_Long:=center_of_gravity_Long-center_of_gravity_Long[No==1], by = (area)]
center_of_gravity <- setDT(center_of_gravity)[, if (.N>1) .SD, by=.(area)]

ggplot() + theme_bw() + theme() +
  geom_path(data=center_of_gravity[!area%in%"x"], aes(x=relative_Long, y=relative_Lat, colour=area))+
  geom_point(data=center_of_gravity[!area%in%"x"], aes(x=relative_Long, y=relative_Lat, colour=area)) + 
  facet_wrap(~area)




#== bubble plot ==#
library("rnaturalearth")
library("rnaturalearthdata")
library("sf")
library("rnaturalearthhires")
library("ggspatial") #for scale bar

# make figure #
#startpoint <- data03_EK$EK_38.df %>% group_by(Mission) %>% filter(row_number()==1)
w <- ne_countries(scale = "medium", returnclass = "sf")
spdf04 <- data.frame(long=spdf$long, lat=spdf$lat, area=spdf$area, month="04")
spdf05 <- data.frame(long=spdf$long, lat=spdf$lat, area=spdf$area, month="05")
spdf06 <- data.frame(long=spdf$long, lat=spdf$lat, area=spdf$area, month="06")
spdf07 <- data.frame(long=spdf$long, lat=spdf$lat, area=spdf$area, month="07")
spdf08 <- data.frame(long=spdf$long, lat=spdf$lat, area=spdf$area, month="08")
spdf_month <- data.table(rbind(spdf04, spdf05, spdf06, spdf07, spdf08))
rm(spdf04,spdf05, spdf06, spdf07,spdf08)

data <- data.table(rbind(sandeel.dt, School_EROS.dt[Frequency%in%200 & category%in%"SAND" & !area %in% "outside"])) #sandeel.dt #rbind(sandeel.dt, School_EROS.dt[Frequency%in%200 & category%in%"SAND" & !area %in% "outside"])
data$month <- strftime(data$YMD_time, "%m", tz="UTC")
data$week <- strftime(data$YMD_time, format="%W", tz="UTC")
gps.dt$week <- strftime(gps.dt$YMD_time, format="%W", tz="UTC")
max(data$sA)


l <- c("April", "May", "June", "July", "August")
names(l) <- c("04", "05", "06", "07", "08")

## "AlbjoernLing", "Engelsk_Klondyke", "Vikingbanken", "Nordgyden", "Ostbanken", "Outer_Shoal"
## "Inner_Shoal_East_2016", "Inner_Shoal_North", "Inner_Shoal_test", "Inner_Shoal_West_2018"
## "Vestbanken_North", "VestbankenSouthEast", "VestbankenSouthWest"

a = c("Vestbanken_North", "VestbankenSouthEast", "VestbankenSouthWest")
spdf_month.dt <- spdf_month[month %in% unique(gps.dt[area%in%a]$month)]

#Engelsk_Klondyke : xlim = c(3.75, 4.6), ylim=c(57.5, 57.85) 
#Innershoal       : xlim = c(3, 4.6), ylim = c(56.55, 57.2)
#Vestbanken       : xlim = c(4.75, 6.7), ylim = c(56.7, 57.5)
#Vinkingbanken    : xlim = c(2.47, 2.83), ylim=c(60.1, 60.7)
#AlbjoernLing     : xlim = c(2.4, 3.4), ylim=c(57.4, 58.2)
#Ostbanken        : xlim = c(3, 4), ylim=c(57.6, 57.9)
#Outer_Shoal      : xlim = c(3.82, 5.1), ylim=c(57.09, 57.53)


#ggplot() +
ggplot(data = w) + geom_sf() + coord_sf(xlim = c(4.75, 6.7), ylim = c(56.7, 57.5), expand = FALSE, datum = NA)+ 
  theme_bw(base_size=15) + theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(), axis.text = element_text(size=5), legend.text = element_text(size=12), legend.text.align = 0.5, legend.title = element_text(size=15, hjust = 0.5 ))+ #, strip.text = element_text(size = 8, margin = margin(1,0,1,0, "mm"))
  #scale_y_continuous(breaks = c(57.5, 57.6, 57.7, 57.8)) + #, labels = c("56.8", "57.0", "57.2")
  #scale_x_continuous(breaks = c(3.8, 4, 4.2, 4.4)) + #, labels = c("56.8", "57.0", "57.2")
  #annotation_scale(location = "bl") + #scale bar
  #geom_polygon(data=spdf_month.dt[area%in%a], aes(long, lat, group=area), colour="black", alpha =0.2) + 
  geom_point(data=gps.dt[area%in%a & !area%in%"outside"], aes(x=Longitude, y=Latitude, colour=vessel), size=.05, alpha =0.2) + #theme(legend.position = "none", axis.title = element_blank())+
  #geom_point(data=data[area%in%a], aes(Longitude, Latitude, size = sA), alpha = 0.5)+ 
  #scale_size_continuous(limits = c(0, 439373.7), range = c(0.1,20), breaks = c(500,5000, 10000, 50000), 
  #                      name = expression(atop("",atop(textstyle("Sandeel"), 
  #                                                     # atop(textstyle("target"),
  #                                                     atop(textstyle("school NASC"),
  #                                                          atop(textstyle("("*~ m^2~nmi^-2*')'))))))
  #                      )+
  #scale_color_grey(name="month")+
  #facet_wrap(~month, labeller = labeller(month=l))+ #, scales="free"
  facet_wrap(~week)+
  labs(x="Longitude", y="Latitude")
#
#


data <- rbind(sandeel.dt, School_EROS.dt[Frequency%in%200 & category%in%"SAND" & !area %in% "outside"]) #sandeel.dt
data$month <- strftime(data$YMD_time, "%m", tz="UTC")
data <- subset(data, data$area=="VestbankenSouthWest") #"VestbankenSouthWest" / "Engelsk_Klondyke"


#
summary(lm(Latitude~month, data=data))



#==============================================================#
####     NASC change by area (large scale distribution)     ####
#==============================================================#

#== areas more than 1 coverage ==#
data$No <- as.numeric(data$No)
a <- data.table(aggregate(data[!coverage_name%in%"x"]$No, list(data[!coverage_name%in%"x"]$area), FUN=max))
a <- a[x>1]$Group.1

ggplot()+theme_bw()+theme(axis.title.x=element_blank(),axis.text.x = element_text(angle = 90), legend.position = "bottom", panel.spacing = unit(0, "null"))+
  geom_boxplot(data=data[!coverage_name%in%"x" & area%in%a], aes(x=as.factor(format(as.POSIXct(time_mean, 'UTC'), format="%m-%d")), y=log(sA), fill=vessel))+
  facet_grid(.~area, scales="free_x")+
  labs(y="log(school NASC)")
#
ggplot()+theme_bw()+theme(axis.title.x=element_blank(),axis.text.x = element_text(angle = 90), legend.position = "bottom", panel.spacing = unit(0, "null"))+
  geom_boxplot(data=data[!coverage_name%in%"x" & area%in%a], aes(x=as.factor(format(as.POSIXct(time_mean, 'UTC'), format="%m-%d")), y=log(sA), fill=vessel))+
  facet_grid(.~area, scales="free_x")+
  labs(y="log(school NASC)")







#=============================#
#### time series analysis  ####
#=============================#

#== coverage data ==#
data <- rbind(sandeel.dt, School_EROS.dt[Frequency%in%200 & category%in%"SAND" & !area %in% "outside" ]) #rbind(sandeel.dt, School_EROS.dt[Frequency%in%200 & category%in%"SAND" & !area %in% "outside" ]) #sandeel.dt #& school_area >= median(School_EROS.dt$school_area)
data$month <- strftime(data$YMD_time, "%m", tz="UTC")
data <- data[order(vessel, area, YMD_time),]
setDT(data)[, time_diff:=as.numeric(difftime(data$YMD_time, lag(data$YMD_time), units = "hours"))]
setDT(data)[, coverage:=as.numeric(1)]
data$coverage <- as.numeric(data$coverage)

#== run by vessel ==#
v = as.character("SD1032") # "SD1031" / "SD1032" / "EROS"
tmp <- data[vessel %in% v] 

#==============================================================#
for (i in 2:nrow(tmp)){
  if (tmp$time_diff[i] >= 24)                                         #if time_diff is over 24 hours
    tmp$coverage[i] <- tmp$coverage[(i-1)] + 1                        #coverage number + 1
  else if (tmp$area[i] != tmp$area[(i-1)])                            #if time_diff is less than 24h and area[i] is not equal to area[i-1]
    tmp$coverage[i] <- tmp$coverage[(i-1)] + 1                        #coverage number + 1
  else if (tmp$area[i] != tmp$area[(i-1)] &&                          #if time_diff is less than 24h and area[i] is not equal to area[i-1],
           nrow(filter(tmp[i:(i+49)], area == tmp$area[i]))>=40 &&    # and if area[i] continues more than 40 in the next 50 rows
           tmp$area[i] != tmp[coverage == coverage[i-1]]$area[1])     # and if area[i] is not equal to...
    tmp$coverage[i] <- tmp$coverage[(i-1)] + 1                        #coverage number + 1
  else
    tmp$coverage[i] <- tmp$coverage[(i-1)]                            #if not, coverage number[i] = coverage number [i-1]
}
#==============================================================#



tmp[, .(cnt= sum(.N)), by= c("coverage", "area")]
ggplot() + my_theme() + theme(axis.title = element_blank(), axis.text = element_text(size=5,), axis.ticks.length  = unit(1, "mm"), strip.text = element_text(size = 7))+
  geom_path(data = gps.dt[vessel %in% v], aes(x = Longitude, y = Latitude)) + 
  geom_point(data = tmp, aes(Longitude, Latitude, colour=as.factor(vessel))) + 
  scale_y_continuous(labels = scales::number_format(accuracy = 0.1)) +
  facet_wrap(~coverage, scales="free")
assign(paste("tmp", v, sep = "_"), tmp)

## combine 3 data.table ## (after making 3 data.frame)
data <- data.table(rbind(tmp_EROS, tmp_SD1031, tmp_SD1032))
setDT(data)[, time_diff:=NULL]
rm(tmp_EROS, tmp_SD1031, tmp_SD1032, tmp)

#== count number of schools  ==#
data[, .(cnt= sum(.N)), by= c("vessel", "coverage", "area")]
gps.dt[, .(cnt= sum(.N)), by= c("vessel", "coverage", "area")]

#== define coverage name ==#
setDT(data)[, coverage_no := paste(vessel, coverage, sep = "-")]
name <- as.data.table(as.table(with(data,by(area,coverage_no,function(xx)names(which.max(table(xx)))))))
setDT(name)[, vessel := gsub('-.*',"",coverage_no)]
setDT(name)[, group_no := order(coverage_no), by  = c("N","vessel")]
setDT(name)[, coverage := ifelse(gsub('.*-',"",name$coverage_no)==("F") | gsub('.*-',"",name$coverage_no)==("x"), gsub('.*-',"",coverage_no), paste(vessel, N, group_no, sep="-"))]
temp <- data.table(coverage_no = name$coverage_no, coverage_name = name$coverage)
data <- merge(x = data, y = temp, by = "coverage_no", all.x = TRUE)
setDT(data)[, sA_sum:= sum(sA), by=c("coverage_name", "vessel")]


#== check if the name correctly assigned ==#
v<- "SD1031"
ggplot() + my_theme() + 
  geom_path(data = gps.dt[!area %in% "outside" & !coverage_name %in% "x" & vessel %in% v ], 
            aes(x = Longitude, y = Latitude), lwd =.1) +
  #geom_polygon(data= spdf, aes(long,lat, group=area), col="black", alpha=.2) + 
  geom_point(data = data[vessel %in% v],
             aes(x = Longitude, y = Latitude), 
             shape = 1, size = 1, colour = "red") + 
  facet_wrap(~coverage_name, scales = "free")
#==============================#
x_gps <- with(gps.dt, aggregate(gps.dt[,c("Latitude", "Longitude", "YMD_time")], list(coverage_name, distance_sum, vessel), mean))
setnames(x_gps, c("Group.1", "Group.2", "Group.3"), c("coverage_name", "distance_sum", "vessel"))
x_dat <- with(data, aggregate(data[,c("Latitude", "Longitude", "YMD_time")], list(coverage_name, sA_sum), mean))
setnames(x_dat, c("Group.1", "Group.2"), c("coverage_name", "sA_sum"))
x <- data.table(merge(x = x_gps, y = x_dat, by = "coverage_name", all.x = TRUE))
x$month.x <- strftime(x$YMD_time.x, "%m", tz="UTC")
ggplot(data=x[!coverage_name%in%c("F","x")]) + theme(legend.position = "none") +
  geom_polygon(data=spdf, aes(long,lat, group=area), col="black", alpha=.2)+
  geom_point(aes(Longitude.x, Latitude.x, colour=coverage_name), shape=1) + 
  geom_point(aes(Longitude.y, Latitude.y, colour=coverage_name), shape=2) + 
  scale_y_continuous(limits = c(56.5,58.5))+
  facet_wrap(month.x~vessel)


#==  calculate sL   ==#
x <- x[!coverage_name%in%c("F","x")]
x$sL <- x$sA_sum/x$distance_sum
setDT(x)[, area:=sub(".*- *(.*?) *-.*", "\\1", x$coverage_name)]
x <- x[order(area, YMD_time.x),]
setDT(x)[, group_no := order(YMD_time.x), by  = c("area")]

cov_name <- x[!is.na(sA_sum) & !area%in%"Nordgyden"]$coverage_name

ggplot() +theme_bw() + theme(legend.position = "none", panel.grid.major = element_blank(), panel.grid.minor = element_blank(), axis.title.x = element_blank(),axis.title.y = element_blank(), axis.text = element_text(size=5,), axis.ticks.length  = unit(1, "mm"), strip.text = element_text(size = 7))+
  geom_path(data = gps.dt[coverage_name %in% cov_name], 
            aes(Longitude, Latitude, colour = vessel)) + 
  scale_y_continuous(labels = scales::number_format(accuracy = 0.1)) + 
  facet_wrap(~coverage_name, scales="free")

ggplot(data = x[!is.na(sA_sum) & 
                  !area%in%"Nordgyden" & 
                  !coverage_name %in% c("SD1031-Inner_Shoal_North-1", "SD1032-Inner_Shoal_East_2016-1")],
       aes(x=YMD_time.x, y=log(sL), colour=vessel))+
  theme_bw() + my_theme() + theme(legend.position = "none", axis.title.x = element_blank())+
  geom_point() +
  geom_text(aes(label = area), hjust = 0.5,  vjust = 0, size = 3) +
  #facet_wrap(~area, scales="free_x")+ 
  labs(y="log(total school NASC / travel distance)")






#======================#
####  Ping distance ####
#======================#
library("rjson")
#SD1032
test <- fromJSON(file="S2019_SAILDRONE_1032/EXPORT/bottomEchogramPlot_T20190430_00595792-20190819_18193333.json")   
#SD1031
test <- fromJSON(file="S2019_SAILDRONE_1031/EXPORT/bottomEchogramPlot_T20190424_10291908-20190820_12575243.json") 
#EROS
test <- fromJSON(file="S2019847_PEROS_3317/EXPORT/bottomEchogramPlot_T20190423_16561743-20190512_19512565.json") 

test <- data.table(PingNumber = test$pingNumber, PingDistance = as.numeric(test$vesselDistance))
setDT(test)[, Diff:=c(0, diff(test$PingDistance))][, distance:= Diff*1852][,Diff:=NULL][,PingDistance:=NULL]
summary(test$distance)
#
#
