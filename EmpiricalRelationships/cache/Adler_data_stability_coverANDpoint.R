rm(list=ls())

#set working directory
wd = "/Users/atredenn/Documents/Projects/Diversity_Stability/"
setwd(wd)
getwd()

library(plyr)

### Arizona data ###

#read in data from point and polygon files
pointdata.az <- read.csv("/Users/atredenn/Documents/Projects/Diversity_Stability/Arizona_Data/AZ_allrecords_point_features.csv")
pointdata.az <- as.data.frame(pointdata.az)
polydata.az <- read.csv("/Users/atredenn/Documents/Projects/Diversity_Stability/Arizona_Data/allrecords_polygon_features.csv")
polydata.az <- as.data.frame(polydata.az)

#subset the data for columns of interest
points <- subset(pointdata.az, select=c(quad, year, Species, Canopy_cov))

#take out zero cover points to calculate average cover for species
# points.nozero <- points[points$Canopy_cov != 0,]
# 
# #calculate average cover (over the entire dataset) for species mapped as points
# avg.cov.points <- ddply(points.nozero, .(Species), summarise, 
#                    cov = mean(Canopy_cov)
# )

#apply average cover values to all records according to spcecies ID
#first apply blanket average to account for all non-measured species
# tot.avg <- mean(avg.cov.points[,2])
# points$Canopy_cov <- tot.avg
points$Canopy_cov <- abs(rnorm(length(points$Canopy_cov), 0, 1))

# #now apply the species-specific values for those that were measured
# for (i in 1:length(avg.cov.points$Species)){
#   points[points$Species == avg.cov.points[i,1], 4] <- avg.cov.points[i,2]
# }



polys <- subset(polydata.az, select=c(quad, year, Species, Area))

colnames(points) <- colnames(polys)

data.az <- rbind(points, polys)
data.az <- data.az[order(data.az$quad, data.az$year),]
names(data.az)

# data.az$Area <- rnorm(length(data.az$Area), 0, 1)
data.az$Area <- 1
# data.az <- data.az[data.az$Area != 0,]

df.agg.az <- ddply(data.az, .(quad, year, Species), summarise, 
                   sum = sum(Area),
                   numspecies = length(Species)
)

df.spp.az <- ddply(df.agg.az, .(quad, year), summarise,
                   sum = sum(sum),
                   spp = length(Species),
                   quadspp = sum(numspecies)
)

quad.names <- unique(df.spp.az$quad)
quadyears.simpson <- matrix(ncol=length(quad.names), nrow=20)
for (i in 1:length(quad.names)){
  index <- which(df.agg.az$quad == quad.names[i])
  data.now <- df.agg.az[index,]
  years <- unique(data.now$year)
 
  for (j in 1:length(years)){
    index.year <- which(data.now$year == years[j])
    data.year <- data.now[index.year,]
    
    simps.start <- data.year$numspecies/sum(data.year$numspecies) 
    quadyears.simpson[j,i] <- sum(simps.start^2)
  }
}

quadyears.simpson <- c(quadyears.simpson)
quadyears.simpson <- quadyears.simpson[!is.na(quadyears.simpson)]
df.spp.az$simpson <- quadyears.simpson

df.cv.az <- ddply(df.spp.az, .(quad), summarise,
                  cv = mean(sum)/sd(sum),
                  spp = mean(spp),
                  simp = mean(1-simpson)
)

par(mfrow=c(3,2), tck=-0.02, mgp=c(2.5,0.7,0), las=1, mar=c(5.1, 4.5, 2, 2.1))
plot(df.cv.az$spp, df.cv.az$cv, xlab="", main="",
     ylab=expression(paste("Cover Stability (", mu/sigma, ")")), cex=0.5, ylim=c(0,9),
     cex.lab=1.5)
x = df.cv.az$spp
y = df.cv.az$cv
model <- lm(y ~ x)
summary(model)
newx <- seq(min(df.cv.az$spp), max(df.cv.az$spp), 0.5)
pred <- predict(model, newdata=data.frame(x=newx), interval=c("confidence"), 
                       level=0.95, type="response")
lines(newx, pred[,1], lwd=2)
# lines(newx, pred[,2], lwd=2, lty="dashed", col="steelblue")
# lines(newx, pred[,3], lwd=2, lty="dashed", col="steelblue")
text(1.7,4, "Neutral",font=4, col="darkorange")

plot(df.cv.az$simp, df.cv.az$cv, xlab="", main="",
     ylab=expression(paste("Cover Stability (", mu/sigma, ")")), cex=0.5, 
     ylim=c(-5,5), xlim=c(0,1), cex.lab=1.5)
x = df.cv.az$simp
y = df.cv.az$cv
model <- lm(y ~ x)
summary(model)
newx <- seq(min(df.cv.az$simp), max(df.cv.az$simp), 0.05)
pred <- predict(model, newdata=data.frame(x=newx), interval=c("confidence"), 
                level=0.95, type="response")
lines(newx, pred[,1], lwd=2)
# lines(newx, pred[,2], lwd=2, lty="dashed", col="steelblue")
# lines(newx, pred[,3], lwd=2, lty="dashed", col="steelblue")
text(0.2,9, "Weak Positive",font=4, col="steelblue")


# #Arizona POLYGON only data##
# data.az <- polys
# data.az <- data.az[order(data.az$quad, data.az$year),]
# names(data.az)
# 
# data.az <- data.az[data.az$Area != 0,]
# 
# df.agg.az <- ddply(data.az, .(quad, year, Species), summarise, 
#                    sum = sum(Area)
# )
# 
# df.spp.az <- ddply(df.agg.az, .(quad, year), summarise,
#                    sum = sum(sum),
#                    spp = length(Species)
# )
# 
# df.cv.az <- ddply(df.spp.az, .(quad), summarise,
#                   cv = mean(sum)/sd(sum),
#                   spp = mean(spp)
# )
# 
# plot(df.cv.az$spp, df.cv.az$cv, xlab="Average Species Richness", main="Arizona (polygons)",
#      ylab=expression(paste("Cover Stability (", mu/sigma, ")")), cex=0.5, ylim=c(0,4))
# x = df.cv.az$spp
# y = df.cv.az$cv
# model <- lm(y ~ x)
# summary(model)
# newx <- seq(min(df.cv.az$spp), max(df.cv.az$spp), 0.5)
# pred <- predict(model, newdata=data.frame(x=newx), interval=c("confidence"), 
#                 level=0.95, type="response")
# lines(newx, pred[,1], lwd=2, col="steelblue")
# lines(newx, pred[,2], lty="dashed", lwd=2, col="steelblue")
# lines(newx, pred[,3], lty="dashed", lwd=2, col="steelblue")
# text(1.4,4, "Positive",font=4, col="steelblue")





### Montana data ###

#read in data from point and polygon files
pointdata.mt <- read.csv("/Users/atredenn/Documents/Projects/Diversity_Stability/Montana_Data/Montana_allrecords_density.csv")
pointdata.mt <- as.data.frame(pointdata.mt)
polydata.mt <- read.csv("/Users/atredenn/Documents/Projects/Diversity_Stability/Montana_Data/Montana_allrecords_cover.csv")
polydata.mt <- as.data.frame(polydata.mt)

#subset the data for columns of interest
points.mt <- subset(pointdata.mt, select=c(quad, year, Species))
polys.mt <- subset(polydata.mt, select=c(quad, year, Species, Basal, Area))

#take out polygon data where basal cover was measured
polys.mt <- polys.mt[polys.mt$Basal=="N",]

#calculate average cover for mean cover value of annuals and apply to observations
avg.cov <- mean(polys.mt$Area)
sd.cov <- sd(polys.mt$Area)
cover.vals <- abs(rnorm(length(points.mt[,1]), 0, 1))
points.mt["Area"] <- cover.vals

polys.mt <- subset(polys.mt, select=c(quad, year, Species, Area))


###ALL MONTANA DATA ANALYSIS###
data.mt <- rbind(points.mt, polys.mt)
data.mt <- data.mt[order(data.mt$quad, data.mt$year),]
names(data.mt)

data.mt$Area <- abs(rnorm())

df.agg.mt <- ddply(data.mt, .(quad, year, Species), summarise, 
                   sum = sum(Area),
                   numspecies = length(Species)
)

df.spp.mt <- ddply(df.agg.mt, .(quad, year), summarise,
                   sum = sum(sum),
                   spp = length(Species),
                   quadspp = sum(numspecies)
)

quad.names <- unique(df.spp.mt$quad)
quadyears.simpson <- matrix(ncol=length(quad.names), nrow=20)
for (i in 1:length(quad.names)){
  index <- which(df.agg.mt$quad == quad.names[i])
  data.now <- df.agg.mt[index,]
  years <- unique(data.now$year)
  
  for (j in 1:length(years)){
    index.year <- which(data.now$year == years[j])
    data.year <- data.now[index.year,]
    
    simps.start <- data.year$numspecies/sum(data.year$numspecies) 
    quadyears.simpson[j,i] <- sum(simps.start^2)
  }
}

quadyears.simpson <- c(quadyears.simpson)
quadyears.simpson <- quadyears.simpson[!is.na(quadyears.simpson)]
df.spp.mt$simpson <- quadyears.simpson

df.cv.mt <- ddply(df.spp.mt, .(quad), summarise,
                  cv = mean(sum)/sd(sum),
                  spp = mean(spp),
                  simp = mean(1-simpson)
)

plot(df.cv.mt$spp, df.cv.mt$cv, xlab="", main="",
     ylab=expression(paste("Cover Stability (", mu/sigma, ")")), cex=0.5, ylim=c(0,5),
     cex.lab=1.5)
x = df.cv.mt$spp
y = df.cv.mt$cv
model <- lm(y ~ x)
summary(model)
newx <- seq(min(df.cv.mt$spp), max(df.cv.mt$spp), 0.5)
pred <- predict(model, newdata=data.frame(x=newx), interval=c("confidence"), 
                level=0.95, type="response")
lines(newx, pred[,1], lwd=2)
text(2.5,5, "Neutral",font=4, col="darkorange")

plot(df.cv.mt$simp, df.cv.mt$cv, xlab="", main="",
     ylab=expression(paste("Cover Stability (", mu/sigma, ")")), cex=0.5, 
     ylim=c(0,4), xlim=c(0,1), cex.lab=1.5)
x = df.cv.mt$simp
y = df.cv.mt$cv
model <- lm(y ~ x)
summary(model)
newx <- seq(min(df.cv.mt$simp), max(df.cv.mt$simp), 0.05)
pred <- predict(model, newdata=data.frame(x=newx), interval=c("confidence"), 
                level=0.95, type="response")
lines(newx, pred[,1], lwd=2)
lines(newx, pred[,2], lwd=2, lty="dashed")
lines(newx, pred[,3], lwd=2, lty="dashed")
# lines(newx, pred[,2], lwd=2, lty="dashed", col="steelblue")
# lines(newx, pred[,3], lwd=2, lty="dashed", col="steelblue")
text(0.18,3.95, "Weak Negative",font=4, col="red")



# ###PERRENNIAL MONTANA DATA###
# data.mt <- polys.mt
# data.mt <- data.mt[order(data.mt$quad, data.mt$year),]
# names(data.mt)
# 
# data.mt <- data.mt[data.mt$Area != 0,]
# 
# df.agg.mt <- ddply(data.mt, .(quad, year, Species), summarise, 
#                    sum = sum(Area)
# )
# 
# df.spp.mt <- ddply(df.agg.mt, .(quad, year), summarise,
#                    sum = sum(sum),
#                    spp = length(Species)
# )
# 
# df.cv.mt <- ddply(df.spp.mt, .(quad), summarise,
#                   cv = mean(sum)/sd(sum),
#                   spp = mean(spp)
# )
# 
# plot(df.cv.mt$spp, df.cv.mt$cv, xlab="Average Species Richness", main="Montana (perennials)",
#      ylab=expression(paste("Cover Stability (", mu/sigma, ")")), cex=0.5)
# x = df.cv.mt$spp
# y = df.cv.mt$cv
# model <- lm(y ~ x)
# summary(model)
# newx <- seq(min(df.cv.mt$spp), max(df.cv.mt$spp), 0.5)
# pred <- predict(model, newdata=data.frame(x=newx), interval=c("confidence"), 
#                 level=0.95, type="response")
# lines(newx, pred[,1], lwd=2)
# lines(newx, pred[,1], lwd=2)
# lines(newx, pred[,2], lty="dashed", lwd=2)
# lines(newx, pred[,3], lty="dashed", lwd=2)
# text(1.7,2.4, "Positive",font=4, col="steelblue")




### Idaho data ###

#read in data from point and polygon files
pointdata.id <- read.csv("/Users/atredenn/Documents/Projects/Diversity_Stability/Idaho_Data/Idaho_allrecords_density.csv")
pointdata.id <- as.data.frame(pointdata.id)
#remove duolicates bewteen point and poly data
pointdata.id <- pointdata.id[pointdata.id$stem=="N",]
polydata.id <- read.csv("/Users/atredenn/Documents/Projects/Diversity_Stability/Idaho_Data/Idaho_allrecords_cover.csv")
polydata.id <- as.data.frame(polydata.id)

#subset the data for columns of interest
points.id <- subset(pointdata.id, select=c(quad, year, species))
polys.id <- subset(polydata.id, select=c(quad, year, species, area))

#calculate average cover for mean cover value of polygons and apply to observations
avg.cov <- mean(polys.id$area)
sd.cov <- sd(polys.id$area)
cover.vals <- abs(rnorm(length(points.id[,1]), 0, 1))
points.id["area"] <- cover.vals

polys.id <- subset(polys.id, select=c(quad, year, species, area))


###ALL IDAHO DATA ANALYSIS###
data.id <- rbind(points.id, polys.id)
data.id <- polys.id
data.id <- data.id[order(data.id$quad, data.id$year),]
names(data.id)

data.id <- data.id[data.id$area != 0,]

dom.spp <- c("Poa secunda", "Artemisia tripartita", "Hesperostipa comata", "Pseudoroegneria spicata")
data.poa <- data.id[data.id$species == dom.spp[1],]
data.art <- data.id[data.id$species == dom.spp[2],]
data.hes <- data.id[data.id$species == dom.spp[3],]
data.pse <- data.id[data.id$species == dom.spp[4],]

data.poano <- data.id[data.id$species != dom.spp[1],]
data.artno <- data.id[data.id$species != dom.spp[2],]
data.hesno <- data.id[data.id$species != dom.spp[3],]
data.pseno <- data.id[data.id$species != dom.spp[4],]
data.id.rare <- rbind(data.poano, data.artno, data.hesno, data.pseno)
data.id.rare$species <- "rare"

data.id <- rbind(data.poa, data.art, data.hes, data.pse, data.id.rare)

data.id <- data.id[order(data.id$quad, data.id$year),]



df.agg.id <- ddply(data.id, .(quad, year, species), summarise, 
                   sum = sum(area),
                   numspecies = length(species)
)


q1.df <- ddply(df.agg.id, .(year, species), summarise, 
               avg = mean(sum),
               numspecies = mean(numspecies)
)
q1.df <- q1.df[q1.df$year != 73,]
q1.df <- q1.df[q1.df$species != "rare",]

library(ggplot2)
ggplot(data=q1.df, aes(x=year, y=(avg*100))) + 
  geom_line(aes(color=species)) +
  geom_point(color="white", size=3) +
  geom_point(aes(color=species), size=2) +
  theme_bw() +
  xlab("Year (19xx)") + ylab("Mean Cover (%)") +
  scale_color_discrete("") +
  theme(axis.title.x = element_text(size=14),
        axis.title.y = element_text(size=14, angle=90), 
        axis.text.x = element_text(size=12), 
        axis.text.y = element_text(size=12), 
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        legend.position = c(0.25,0.8),
        legend.key = element_blank(),
        legend.text=element_text(size=10)
  )



df.spp.id <- ddply(df.agg.id, .(quad, year), summarise,
                   sum = sum(sum),
                   spp = length(species),
                   quadspp = sum(numspecies)
)

quad.names <- unique(df.spp.id$quad)
quadyears.simpson <- matrix(ncol=length(quad.names), nrow=30)
for (i in 1:length(quad.names)){
  index <- which(df.agg.id$quad == quad.names[i])
  data.now <- df.agg.id[index,]
  years <- unique(data.now$year)
  
  for (j in 1:length(years)){
    index.year <- which(data.now$year == years[j])
    data.year <- data.now[index.year,]
    
    simps.start <- data.year$numspecies/sum(data.year$numspecies) 
    quadyears.simpson[j,i] <- sum(simps.start^2)
  }
}

quadyears.simpson <- c(quadyears.simpson)
quadyears.simpson <- quadyears.simpson[!is.na(quadyears.simpson)]
df.spp.id$simpson <- quadyears.simpson

df.cv.id <- ddply(df.spp.id, .(quad), summarise,
                  cv = sd(sum)/mean(sum),
                  spp = mean(spp),
                  simp = mean(1-simpson)
)


hist(df.cv.id$cv, freq=FALSE, col="grey70", border="grey70", xlim=c(0,1.5), 
     ylim=c(0,2), xlab="Temporal C.V.", main="")
lines(density(df.cv.id$cv, adjust=1), lwd=4, col="black")
# text(x=1.5, y=c(1.7,1.5,1.3,1.1,0.9), c("ARTR", "HECO", "POSE", "PSSP", "rare"), cex=0.8)
# text(x=1.5, y=1.9, "Species", cex=1.2)
lines(x=rep(median(df.cv.id$cv),3), y=seq(0,2), lty="dashed", lwd=2, col="white")

library(ggplot2)
ggplot() +
  geom_histogram(aes(x=df.cv.id$cv, y=..density..), binwidth=0.2, fill="grey") +
  geom_line(aes(x=df.cv.id$cv), adjust=2, size=1, stat="density") +
  theme_bw()

  plot(df.cv.id$spp, df.cv.id$cv, xlab="Average species Richness", main="",
     ylab=expression(paste("Cover Stability (", mu/sigma, ")")), cex=0.5, ylim=c(0,6),
     cex.lab=1.5)
x = df.cv.id$spp
y = df.cv.id$cv
model <- lm(y ~ x)
summary(model)
newx <- seq(min(df.cv.id$spp), max(df.cv.id$spp), 0.5)
pred <- predict(model, newdata=data.frame(x=newx), interval=c("confidence"), 
                level=0.95, type="response")
lines(newx, pred[,1], lwd=2)
lines(newx, pred[,2], lwd=2, lty="dashed")
lines(newx, pred[,3], lwd=2, lty="dashed")
text(10,3.9, "Positive",font=4, col="steelblue")

plot(df.cv.id$simp, df.cv.id$cv, xlab="Simpson's Diversity", main="",
     ylab=expression(paste("Cover Stability (", mu/sigma, ")")), cex=0.5, 
     ylim=c(0,4), xlim=c(0,1), cex.lab=1.5)
x = df.cv.id$simp
y = df.cv.id$cv
model <- lm(y ~ x)
summary(model)
newx <- seq(min(df.cv.id$simp), max(df.cv.id$simp), 0.05)
pred <- predict(model, newdata=data.frame(x=newx), interval=c("confidence"), 
                level=0.95, type="response")
lines(newx, pred[,1], lwd=2)
lines(newx, pred[,2], lwd=2, lty="dashed")
lines(newx, pred[,3], lwd=2, lty="dashed")
text(0.18,3.95, "Weak Positive",font=4, col="steelblue")


# ###POLYGON IDAHO DATA ANALYSIS###
# data.id <- polys.id
# data.id <- data.id[order(data.id$quad, data.id$year),]
# names(data.id)
# 
# data.id <- data.id[data.id$area != 0,]
# 
# df.agg.id <- ddply(data.id, .(quad, year, species), summarise, 
#                    sum = sum(area)
# )
# 
# df.spp.id <- ddply(df.agg.id, .(quad, year), summarise,
#                    sum = sum(sum),
#                    spp = length(species)
# )
# 
# df.cv.id <- ddply(df.spp.id, .(quad), summarise,
#                   cv = mean(sum)/sd(sum),
#                   spp = mean(spp)
# )
# 
# plot(df.cv.id$spp, df.cv.id$cv, xlab="Average Species Richness", main="Idaho (polygon data)",
#      ylab=expression(paste("Cover Stability (", mu/sigma, ")")), cex=0.5, ylim=c(1,5), xlim=c(6,10))
# x = df.cv.id$spp
# y = df.cv.id$cv
# model <- lm(y ~ x)
# summary(model)
# newx <- seq(min(df.cv.id$spp), max(df.cv.id$spp), 0.5)
# pred <- predict(model, newdata=data.frame(x=newx), interval=c("confidence"), 
#                 level=0.95, type="response")
# lines(newx, pred[,1], lwd=2)
# text(6.3,4.9, "Neutral",font=4, col="darkorange")
# 



### KANSAS data ###
#read in data
polydata.ks <- read.csv("/Users/atredenn/Documents/Projects/Diversity_Stability/Kansas_Data/KansasData_Adler_Clean.csv")
polydata.ks <- as.data.frame(polydata.ks)

#subset the data for columns of interest
polys.ks <- subset(polydata.ks, select=c(quad, year, species, area))


###POLYGON KANSAS DATA ANALYSIS###
data.ks <- polys.ks
data.ks <- data.ks[order(data.ks$quad, data.ks$year),]
names(data.ks)

data.ks <- data.ks[data.ks$area > 0,]

df.agg.ks <- ddply(data.ks, .(quad, year, species), summarise, 
                   sum = sum(area)
)

df.spp.ks <- ddply(df.agg.ks, .(quad, year), summarise,
                   sum = sum(sum),
                   spp = length(species)
)

df.cv.ks <- ddply(df.spp.ks, .(quad), summarise,
                  cv = mean(sum)/sd(sum),
                  spp = mean(spp)
)

plot(df.cv.ks$spp, df.cv.ks$cv, xlab="Average Species Richness", main="Kansas",
     ylab=expression(paste("Basal Cover Stability (", mu/sigma, ")")), cex=0.5, ylim=c(1.5,4))
x = df.cv.ks$spp
y = df.cv.ks$cv
model <- lm(y ~ x)
summary(model)
newx <- seq(min(df.cv.ks$spp), max(df.cv.ks$spp), 0.5)
pred <- predict(model, newdata=data.frame(x=newx), interval=c("confidence"), 
                level=0.95, type="response")
lines(newx, pred[,1], lwd=2)
lines(newx, pred[,2], lwd=2, lty="dashed")
lines(newx, pred[,3], lwd=2, lty="dashed")
text(5,4, "Positive",font=4, col="steelblue")



# 
# 
# 
# 
# 
# 
# 
# ### CODE FOR PLOTTING TIME-SERIES ###
# 
# par(mfrow=c(2,1))
# df.A1P <- df.spp.az[df.spp.az$quad=="A1P",]
# df.A1P.spp <- df.agg.az[df.agg.az$quad=="A1P",]
# spp <- as.character(unique(df.A1P.spp$Species))
# plot(df.A1P$year, df.A1P$sum, type="lines", col="red", lwd=1.6,
#      ylab="cover (%)", xlab="year (19xx)")
# points(df.A1P$year, df.A1P$sum, pch=21, bg="white", col="white", cex=1.5)
# points(df.A1P$year, df.A1P$sum, pch=21, bg="white", col="red")
# for(i in 1:length(spp)){
#   lines(df.A1P.spp[df.A1P.spp$Species==spp[i],2], df.A1P.spp[df.A1P.spp$Species==spp[i],4],
#         col="grey50", lwd=1.3)
#   points(df.A1P.spp[df.A1P.spp$Species==spp[i],2], df.A1P.spp[df.A1P.spp$Species==spp[i],4],
#          pch=21, col="white", bg="white", cex=1)
#   points(df.A1P.spp[df.A1P.spp$Species==spp[i],2], df.A1P.spp[df.A1P.spp$Species==spp[i],4],
#          col="grey50", cex=0.5)
# }
# 
# df.WD5 <- df.spp.az[df.spp.az$quad=="WD5",]
# df.WD5.spp <- df.agg.az[df.agg.az$quad=="WD5",]
# spp <- as.character(unique(df.WD5.spp$Species))
# plot(df.WD5$year, df.WD5$sum, type="lines", col="red", lwd=1.6, ylim=c(0,0.1),
#      ylab="cover (%)", xlab="year (19xx)")
# points(df.WD5$year, df.WD5$sum, pch=21, bg="white", col="white", cex=1.5)
# points(df.WD5$year, df.WD5$sum, pch=21, bg="white", col="red")
# for(i in 1:length(spp)){
#   lines(df.WD5.spp[df.WD5.spp$Species==spp[i],2], df.WD5.spp[df.WD5.spp$Species==spp[i],4],
#         col="grey50", lwd=1.3)
#   points(df.WD5.spp[df.WD5.spp$Species==spp[i],2], df.WD5.spp[df.WD5.spp$Species==spp[i],4],
#          pch=21, col="white", bg="white", cex=1)
#   points(df.WD5.spp[df.WD5.spp$Species==spp[i],2], df.WD5.spp[df.WD5.spp$Species==spp[i],4],
#          col="grey50", cex=0.5)
# }
# 
# mod = lm (df.WD5$sum ~ df.WD5.spp[df.WD5.spp$Species==spp[1],4])
# mod2 = lm (df.A1P$sum ~ df.A1P.spp[df.A1P.spp$Species==spp[1],4])
# 
# ##Plot all quads with species and total cover
# quads <- as.character(unique(df.spp.az$quad))
# 
# pdf("/users/atredenn/desktop/arizona_plots.pdf", height=5, width=5)
# for(i in 1:length(quads)){
#   df.quad <- df.spp.az[df.spp.az$quad==quads[i],]
#   df.quad.spp <- df.agg.az[df.agg.az$quad==quads[i],]
#   spp <- as.character(unique(df.quad.spp$Species))
#   
#   plot(df.quad$year, df.quad$sum, type="lines", col="red", lwd=1.6, ylim=c(0,0.1),
#        ylab="cover (%)", xlab="year (19xx)", main=quads[i])
#   points(df.quad$year, df.quad$sum, pch=21, bg="white", col="white", cex=1.5)
#   points(df.quad$year, df.quad$sum, pch=21, bg="white", col="red")
#   for(j in 1:length(spp)){
#     lines(df.quad.spp[df.quad.spp$Species==spp[j],2], df.quad.spp[df.quad.spp$Species==spp[j],4],
#           col="grey50", lwd=1.3)
#     points(df.quad.spp[df.quad.spp$Species==spp[j],2], df.quad.spp[df.quad.spp$Species==spp[j],4],
#            pch=21, col="white", bg="white", cex=1)
#     points(df.quad.spp[df.quad.spp$Species==spp[j],2], df.quad.spp[df.quad.spp$Species==spp[j],4],
#            col="grey50", cex=0.5)
#   }
# }
# dev.off()
